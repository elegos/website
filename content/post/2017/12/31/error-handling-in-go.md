---
title: "Error handling in Go"
date: 2017-12-31T12:00:00+02:00
image: ""
showonlyimage: false
draft: false

categories: ["go"]
tags: ["go", "error handling"]
---

Most of the programming languages support multiple ways of handling errors, for example try-catching, value-checking, popping errors in the stack. Learning go I found the approach of this language is way different: you can let a function return an error (and eventual result(s)), thus not throwing any kind of error, and not returning “special values” like, for example, PHP’s `json_decode` (which can return `true`, `false`, `NULL`, `stdClass` or even an `array`!).

In this article I’ll describe what I found being (for me) the most elegant and convenient way of handling errors in Go.

As I previously stated, error generation and handling in Go is made in a way like this:

```golang
import (
  "errors"
  "fmt"
)

func division(dividend int32, divisor int32) (float64, error) {
  if (divisor == 0) {
    return 0, errors.New("Divisor is 0!")
  }

  return float64(dividend) / float64(divisor), nil
}

func main() {
  result, err := division(2, 0)
  if err != nil {
    fmt.Println(fmt.Sprintf("%d/%d is not supported: %s", 2, 0, err))
  } else {
    fmt.Println(fmt.Sprintf("%d/%d = %.2f", 2, 0, result))
  }
}
// Output: 2/0 is not supported: Divisor is 0!
```

The explanation is pretty simple: check if the error is not nil, and if it is, panic or handle the error. Which is fine, unless you have to read and check a series of data.

I’ll reference myself in this by showing you a snippet of code of one mf my projects, [NWN Toolset go](https://github.com/elegos/nwn-toolset-go):

```golang
func extractHeader(file *os.File) (Header, error) {
  var result = Header{}

  bytes, err := fileReader.ReadAndCheck(file, 4)
  if err != nil {
    return result, err
  }
  result.FileType = strings.Trim(string(bytes), "\x00")

  bytes, err = fileReader.ReadAndCheck(file, 4)
  if err != nil {
    return result, err
  }
  result.Version = strings.Trim(string(bytes), "\x00")

  bytes, err = fileReader.ReadAndCheck(file, 4)
  if err != nil {
    return result, err
  }
  result.LanguageCount = fileReader.BytesToUint32LE(bytes)

  bytes, err = fileReader.ReadAndCheck(file, 4)
  if err != nil {
    return result, err
  }
  result.LocalizedStringSize = fileReader.BytesToUint32LE(bytes)

  bytes, err = fileReader.ReadAndCheck(file, 4)
  if err != nil {
    return result, err
  }
  result.EntryCount = fileReader.BytesToUint32LE(bytes)
  // continues for a series of reads...

  return result, nil
}
```

And this is what I ended up with (magic explained later):

```golang
func extractHeader(file *os.File) (Header, error) {
  var readerBag = fileReader.ByteReaderBag{File: file}
  var result = Header{
    FileType:                strings.Trim(fileReader.ReadStringFromBytes(&readerBag, 4), "\x00"),
    Version:                 strings.Trim(fileReader.ReadStringFromBytes(&readerBag, 4), "\x00"),
    LanguageCount:           fileReader.ReadUint32FromBytes(&readerBag),
    LocalizedStringSize:     fileReader.ReadUint32FromBytes(&readerBag),
    EntryCount:              fileReader.ReadUint32FromBytes(&readerBag),
    OffsetToLocalizedString: fileReader.ReadUint32FromBytes(&readerBag),
    OffsetToKeyList:         fileReader.ReadUint32FromBytes(&readerBag),
    OffsetToResourceList:    fileReader.ReadUint32FromBytes(&readerBag),
    BuildYear:               fileReader.ReadUint32FromBytes(&readerBag),
    BuildDay:                fileReader.ReadUint32FromBytes(&readerBag),
    DescriptionStrRef:       fileReader.ReadUint32FromBytes(&readerBag),
  }

  var reservedBytes = fileReader.ReadBytes(&readerBag, 116)

  copy(result.Reserved[:], reservedBytes)

  return result, readerBag.Err
}
```

I assure you this code is 100% equivalent to the previous one, and it’s all of it (i.e. I didn’t truncate it). Much simplier, isn’t it?

I’m not a genious and this is not all of my work. I took inspiration from this [go’s blog post](https://blog.golang.org/errors-are-values). More or less it rightfully states that errors are not 2nd grade citizens and they should be always read and checked against nil, but keeping reading them make the code become ugly very soon (see the previous example!).

Here is explained the magic code, but first some definitions (strait from my project’s sources):

```golang
// ByteReaderBag container used to gracefully manage file reading errors
type ByteReaderBag struct {
  File *os.File
  Err  error
}

// ReadAndCheck reads the data from the file and check whether it has been read
func ReadAndCheck(file *os.File, toRead uint32) ([]byte, error) {
  // Not important for this example, it reads the data and checks for the bytes read
  // in case the read bytes are not the ones requested, it will return a valorised error
}

// ReadBytes read toRead bytes and store any error in the bag
func ReadBytes(readerBag *ByteReaderBag, toRead uint32) []byte {
  // do not process if there is already a previous error in the bag
  if readerBag.Err != nil {
    return nil
  }

  bytes, err := ReadAndCheck(readerBag.File, toRead)

  if err != nil {
    // this will prevent future readings to proceed
    readerBag.Err = err

    return nil
  }

  return bytes
}
```

Let’s first analyse what we previously did in the first, verbose example: a cycle of reads, checking at each iteration the error, and in case returning the value with the error (stopping the code from running). This is what we need to continue behaving like, if we want to keep the same functionality.

`ByteReaderBag` is a struct which contains the reference of a file and an error. It is then passed by pointer to the reading function, which will, in few words, process the reading until an error occours, then it will stop processing, even if still allowing you to call it again and again without having to check the error. After all the calls to `ReadBytes` you can return or handle the error once, and the functionality will be preserved (stop to read in case of error and manage / return the error itself).

This has some implications:

- It’s way more readable
- It will allow programmers to not hate the code (:D)
- It will be way easier to test the code (and maximise the code coverage), having to test the error handling only in one function and not several times for each read/write/whatever. Please take a look at the tests of my project to have an idea ([testing using the reading function](https://github.com/elegos/nwn-toolset-go/blob/master/src/aurora/file/erf/erf_test.go) and [testing the error generation](https://github.com/elegos/nwn-toolset-go/blob/master/src/aurora/tools/fileReader/fileReader_test.go)).

Cool, huh? :)
