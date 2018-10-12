---
title: "Listening on sockets using Go"
date: 2018-10-12T02:30:00+02:00
image: ""
showonlyimage: false
draft: false

categories: ["go"]
tags: ["go", "networking", "multi-threading", "socket"]
---

Listening on sockets allow an application to connect to other devices.
We use this technique daily visiting websites, or connecting to a series of
services via the HTTP(s) protocol. Go comes with a standard library to manage
HTTP connections, but from time to time, that's not the most effective way
to pass data between two systems. This post will show you how to listen on
sockets handling multiple connections.

<!--more-->

## First step: the concept

Before even looking at the code, we need to analyse what we're attempting to do.

First and foremost, we're trying to listen on a socket: this means that when a
host contacts the service, a full duplex connection is established, allowing the
two parts to talk to each other. So we have a listener and a connection. What
happens when another host tries to connect to our service? Nothing, unless another
listener is being set up, repeating the same behaviour.

So we need a loop which listens on a socket, accepting a new connection which will
be handled asynchronously, so that a new listener can immediately be set to get
as many connections as possible.

## Listening on a socket

Go's network package is super simple, compared to, for example, the C language.

Indeed to start listening on a socket, we just need to write something like this:

```go
// ...

import (
  "net"
)

// ...

// Listening on a unix socket
listener, err := net.Listen("unix", "tmp.sock")
// ... error handling

// Blocking action: we're already listening on the socket!
connection, err := listener.Accept()

```

`net.Listen` accepts a series of arguments as network type, and there is a list
[here](https://golang.org/pkg/net/#Dial).

## Managing cancelation

Because the `Accept` method is thread-locking, we need a strategy in order to
cancel it at any time, for example using a channel. This example will use a
context's channel:

```go
// ...

import (
  "log"
  "net"
  "os"
)

// ...

listener, err := net.Listen("unix", "tmp.sock")
// ... error handling

go func() {
  <-myContext.Done()
  listener.Close()
}

connection, err := listener.Accept()
if err != nil {
	// Gracefully exit as the context was canceled
	if ctx.Err() == myContext.Canceled {
		os.Exit(0)
	}

  // Unhandled error
	log.Fatal(err)
}

// ... manage connection here

```

If `listener.Close()` is invoked, it will let the `Accept` method return an error

## Managing the connection

Now that we've got a cancelable listener which produces a connection, we need to
handle it. A connection can be used to read or send data: in this post we'll see
how to read the bytes, but it's not hard to write as well :)

Reading can be done in different ways, for example reading a fixed number of bytes,
or watching for a delimiter, which will be our case for today.

```go
// ...
import (
  "bufio"
  "fmt"
)
// ...

// conn is a connection created by listener.Accept()

// Create a connection's reader
reader := bufio.NewReader(conn)

// Read (blocking) for the next connection message
// The delimiter can be any character, like '\x00'
bytes, err := reader.ReadBytes('\n')

// An error may rise if a read deadline was set on the connection,
// or if the connection was closed by another thread
if err != nil {
  // Manage error here
}

// Remove the delimiter character
bytes := bytes[0 : len(bytes)-1]

// Handle the message
fmt.Println(string(bytes))
```

Obviously a connection can be used several times (think about a protocol, which
exchanges several messages before being closed), so this code will be put in a
loop in a real case scenario.

## Wrapping it up in a multi-threading context

As previously written, both listeners and connections are thread-blockers. If
we try to manage an entire connection before creating a new listener, only one
client might connect at the same time; note that this could be right for application's
design, though not the most common one. Let's see how wrapping the previous code
together looks like, adding some go routines to let the most connections be created
at the same time.

```go
package main

import (
  "bufio"
  "context"
  "fmt"
  "net"
  "sync"
  "time"
)

// You can decide whether to set this constant
// to a big number (say 10 minutes), or not using
// it at all (a connection might be established
// indefinitely or until the remote disconnects).
//
// In our case we'll let the connection timeout
// after just 2 seconds of inactivity
// (for demonstration purposes).
const connectionTimeout = 2 * time.Second

type UnixHandler struct {
  UnixSocketPath string
}

func (handler *UnixHandler) Listen(ctx context.Context) error {
  // Initialize the listener to listen on the UNIX socket
  listener, err := net.Listen("unix", handler.UnixSocketPath)
  if err != nil {
    return err
  }
  defer listener.Close()
  // Close the listener upon context canceling
  go func() {
    <-ctx.Done()
    listener.Close()
  }()

  // This wait group will ensure the messages are
  // being processed before exiting
  messageProcessingWaitGroup := sync.WaitGroup{}
  for true {
    // Accept (blocking) a new connection
    conn, err := listener.Accept()
    if err != nil {
      // Gracefully exit as the context was canceled
      if ctx.Err() == context.Canceled {
        return nil
      }

      return err
    }
    defer conn.Close()
    // Close the connection upon context canceling
    go func() {
      <-ctx.Done()
      conn.Close()
    }()

    // Asynchronously manage the connection so that
    // another connection can be established immediately
    go func() {
      // Create a connection's reader
      reader := bufio.NewReader(conn)
      for true {
        // Set a connection timeout (optional)
        conn.SetReadDeadline(time.Now().Add(connectionTimeout))
        // Read (blocking) for the next connection message
        // The delimiter can be any character, like '\x00'
        bytes, err := reader.ReadBytes('\n')

        // An error may rise on read deadline,
        // or if context is canceled
        // and thus the connection is closed
        if err != nil {
          break
        }

        // Remove the new line delimiter
        bytes = bytes[0 : len(bytes)-1]

        // At this point we've got a message to handle:
        // add it to the wait group
        messageProcessingWaitGroup.Add(1)
        // Do whatever you want with the data asynchronously
        // (for example send it to a message handler).
        // In this way the application will be able to accept
        // other messages in the same connection without waiting
        // for the message to be completely processed.
        //
        // Some designs may require that the messages are being processed
        // synchronously, so in that case just don't wrap it in a go routine.
        go func(bytes []byte) {
          // Handle the message
          fmt.Println(string(bytes))
          // Remove from wait group
          messageProcessingWaitGroup.Done()
        }(bytes)
      }
    }()
  }

  // Ensure that all the listened messages
  // have been correctly processed
  messageProcessingWaitGroup.Wait()

  return nil
}

func main() {
  ctx, cancel := context.WithCancel(context.Background())

  handler := UnixHandler{UnixSocketPath: "tmp.sock"}
  waitGroup := sync.WaitGroup{}
  waitGroup.Add(1)
  go func() {
    err := handler.Listen(ctx)
    if err != nil {
      fmt.Println(err)
    }
    waitGroup.Done()
  }()

  // just for example purposes, cancel the context after 20 seconds
  time.AfterFunc(10*connectionTimeout, cancel)
  waitGroup.Wait()
}
```

If you're compiling this code in a \*nix environment (Linux, OSX, etc), you can
try to send data to the application using netcat:

```bash
nc -U /path/to/tmp.sock
```

Executing this command an interactive shell will open and the connection will be
established: you'll have two seconds (if you don't tweak the code) to write your
first message and hitting `<enter>` to proc the new line character delimiter, as
specified in the code. After that, the timeout will be reset and you'll have two
other seconds to send the second message, and so on so forth. After two seconds
of inactivity, the connection will be closed from the host (our application), and
no further messages will be able to be sent.

The application will stop after 20 seconds due to the main's function code,
canceling the application's context, propagated to our socket handler.

Any questions? Suggestions? Don't hesitate to contact me via email, or in the
comments below!
