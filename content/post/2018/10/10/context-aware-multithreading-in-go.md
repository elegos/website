---
title: "Context-aware multithreading in go"
date: 2018-10-10T02:00:00+02:00
image: ""
showonlyimage: false
draft: false

categories: ["go"]
tags: ["go", "multi-threading", "signals", "context"]
---

Multi-threading has always been the novice programmer's scarecrow, and even
professionals might have never really written asyncrhonous code before, for
a number of reasons: first of all because it's more complicated to think
in an asyncrhonous world! Golang has multi-threading in its heart, and this
is a big deal because it simplifies a number of things.

<!--more-->

In this post I will describe my solution to do two different things:

1. manage two or more threads in a single application
2. manage the SIGINT signal (`CTRL+C`) across the threads

The code in this article contains [go routines](https://tour.golang.org/concurrency/1),
[channels](https://tour.golang.org/concurrency/2),
[structs](https://tour.golang.org/moretypes/2) and
[methods](https://tour.golang.org/methods/1).

## First iteration: asyncrhonous functions

In order to understand the basic concepts, let's read the following pseudo-code:

```
main
  (run different functions at the same time)
  (await for the functions to end)
  exit
```

This iteration shows the first difficulty: how to run multiple functions
at the same time? And how to wait for them before exiting?

The answer to the first question is using go routines. But being asynchronous by
their nature, they won't be waited and the app will immediately exit. And here comes
the answer to the second question: Go has a few options, from using channels to using
[sync.WaitGroup](https://golang.org/pkg/sync/#WaitGroup), which we're going to
use.

Let's write some more go-ish code now:

```go
package main

import (
  "sync"
)

func main() {
  waitGroup := sync.WaitGroup{}
  runners := /*let's say a slice of functions*/

  for _, runner := range runners {
    waitGroup.Add(1)
    go func(r func()) {
      r()
      waitGroup.Done()
    }(runner)
  }
  waitGroup.Wait()
}
```

Don't panic: it might be hard to read it the first time. Here follows the explanation.

First of all we instantiate a new `WaitGroup`. The object's job is to keep track
of a group of "things" to be done, and to wait untill all these things have come
to an end via an internal counter.

Imagine for now that the runners are simple functions that have to be run asynchronously.

With `waitGroup.Add(1)` we're telling the WaitGroup object to wait for one more runner
inside the slice we're cycling. It is important to put this function call in the
same thread where the `waitGroup` operates, as calling this asynchronously might
lead to inconsistent behaviour (`waitGroup.Wait()` might be called before, resulting
in not waiting for the go routines at all).

We then proceed to run each of our runners using go routines, because the execution
of our functions is synchronous and we want to execute them all at the same time.
Note that we're adding the function as parameter of the go routine: this is due
to the fact that we're executing go routines inside a synchronous loop. For more
information: [link](https://github.com/golang/go/wiki/CommonMistakes#using-goroutines-on-loop-iterator-variables "Common mistakes").

The important bit of this loop though is `waitGroup.Done()` inside the go routine:
this function call tells the `WaitGroup` object that a job has finished: inside
the go routine, the code is still synchronous, so as soon as the function ends,
this method is being called. You might defer the `waitGroup.Done()` to the runner,
but I personally think this is prone to bugs, as it might be called more than once,
or not being called at all.

After the loop in the main thread, we eventually call `waitGroup.Wait()`, which
will wait for as many `waitGroup.Done()` calls as many ones we've added via `waitGroup.Add`.

The result of this first iteration will be that the program will execute the functions
all at the same time, untill all of them will end. If any one of them won't end,
the program won't spontaneously terminate.

## Second iteration: SIGINT

Now that we (kinda) know how to manage the go routines, it's time to think about
the SIGINT signal: what happens if the user wants to exit the application before
all the functions have been executed? The previous code will just ignore the pressing
of `CTRL+C`, and the only way to stop the execution is to kill the application (SIGKILL)
(exiting the routines abruptly).

First of all, we need to catch the SIGINT signal, then we need to alert the routines
that the user wants to exit the application, giving them the option to gracefully exit.

As bridge between the event and the routines, we're going to use the context.

```go
package main

import (
  "context"
  "fmt"
  "os"
  "os/signal"
)

func setupSigintTrap(ctx context.Context) context.Context {
  // get the context's cancel function
  appContext, cancel := context.WithCancel(ctx)

  // create a channel dedicated to the SIGINT signal
  interruptChannel := make(chan os.Signal, 1)
  // notify the channel when the Interrupt signal is being fired
  signal.Notify(interruptChannel, os.Interrupt)

  // run the following code asynchronously
  // because otherwise it would be blocking
  go func() {
    // block the execution until the channel is triggered
    <-interruptChannel
    fmt.Println("Received SIGINT signal, stopping...")
    // "cancel" the context
    cancel()
  }()

  return appContext
}
```

The context's cancel function sets the context as "done", which can be managed by
our routines called before. Now we need to let our functions be context-aware,
because otherwise they won't be able to read the context status.

For ease of use, here is a simple struct with the relative `Run` method: it will
replace our pseudo-code runners.

```go
package main

import (
  "context"
  "fmt"
  "time"
)

type MyRunner struct{ Name string }

func (r *MyRunner) Run(ctx context.Context) {
  loop := true

  // cycle until `loop` is true
  for loop {
    fmt.Printf("Executing go routine %s...\n", r.Name)
    <-time.After(2 * time.Second) // hard work here! Block for two seconds

    // select the first that occours
    select {
    case <-ctx.Done(): // context is done! exit the loop
      loop = false
    case <-time.After(0): // wait for 0 seconds (just to fill the channel)
    }
  }

  // we're now finishing the function
  <-time.After(1 * time.Second) // simulate graceful exit, blocking for one more second
}
```

Essentially the meaning of this `Run(context.Context)` method is to loop indefinitely
until the context is "done". It might be a long process, or a finite loop, or
whatever function that must be executed asynchronously. At the end of each loop's
cycle, `select` is used to select the first channel that's set: first we check
for the context, and if it's done we break from the loop altering the guard condition.
Otherwise we wait for 0 seconds, or in other words we proceed with another cycle
immediately as the channel will be instantly triggered (but being in second
position, the case `ctx.Done()` will have the precedence).

Wrapping things up, it all comes to this code:

```go
package main

import (
  "context"
  "fmt"
  "os"
  "os/signal"
  "sync"
  "time"
)

type MyRunner struct{ Name string }

func (r *MyRunner) Run(ctx context.Context) {
  loop := true

  for loop {
    fmt.Printf("Executing go routine %s...\n", r.Name)
    <-time.After(2 * time.Second)

    select {
    case <-ctx.Done():
      loop = false
    case <-time.After(0):
    }
  }

  <-time.After(1 * time.Second)
}

func setupSigintTrap(ctx context.Context) context.Context {
  appContext, cancel := context.WithCancel(ctx)

  interruptChannel := make(chan os.Signal, 1)
  signal.Notify(interruptChannel, os.Interrupt)

  go func() {
    <-interruptChannel
    fmt.Println("Received SIGINT signal, stopping...")
    cancel()
  }()

  return appContext
}

func main() {
  appContext := setupSigintTrap(context.Background())
  waitGroup := sync.WaitGroup{}

  runners := []MyRunner{MyRunner{Name: "R1"}, MyRunner{Name: "R2"}}

  for _, runner := range runners {
    waitGroup.Add(1)
    go func(r MyRunner) {
      fmt.Printf("Adding runner %s...\n", r.Name)
      r.Run(appContext)
      waitGroup.Done()
    }(runner)
  }
  waitGroup.Wait()
}
```

What do you think about it? Do you have any question? Don't hesitate to contact
me adding a comment below :)
