---
title: "Switch to another programming language?"
date: 2018-10-04T17:15:00+02:00
image: ""
showonlyimage: false
draft: false

categories: ["carreer"]
tags: ["go", "php", "carreer"]
---

First and foremost I consider myself a software architect and engineer. My professional
carreer let me focus, from a programming point of view, on web technologies,
mostly the common PHP-JS stack (including obviously HTML and CSS). At least here
in Italy most of the startups live on PHP and NodeJS, while other structured companies
prefere Java and .NET technologies, which I all tried in my professional experience.
Today I'm going to write a couple of lines on why I'd really like to go straight with Golang,
or better why I'm seriosuly considering to switch to a new programming language for
my personal projects and possibly affecting my job applications.

## The reasons

There is no simple reason behind this idea I cultivated since an year now.
My skills obviously focus on object oriented PHP programming, and I'm able to
through-put a high quantity of good quality code, knowing the common coding styles,
most of the common PHP functions, frameworks, typical service infrastructures etc.
PHP is my confort zone, and I consider myself a PHP professional. So why should I
ever want to switch to another, way less known technology?

> *Generally speaking everyone that want to jump into another boat should have this
> clear in mind: no programming language is perfect, but most of the times it's up
> to the developer to show the most weaknesses.*

First of all, I think that the PHP language is awesome for prototyping and, working
in the big data industry, I know for sure it's more than capable of sorting out
most of the tasks of any complexity order, specially from version 7 and up, including
an awesome core rewriting, allowing for blazing fast performances. I know and
I'm aware of the PHP pros and cons. Generally speaking everyone that want to jump
into another boat should have this clear in mind: no programming language is
perfect, but most of the times it's up to the developer to show the most weaknesses.

That said, I started feeling unconfortable with the code written by myself and my
collegues, something that I totally ignored when I first read about in online blogs
and magazines years ago, something that I found on the opposite good and powerful:
something called "*type hierarchy*".

> *A class hierarchy or inheritance tree in computer science is a classification
> of object types, denoting objects as the instantiations of classes (class is
> like a blueprint, the object is what is built from that blueprint) inter-relating
> the various classes by relationships such as "inherits", "extends", "is an
> abstraction of", "an interface definition".[1] In object-oriented programming,
> a class is a template that defines the state and behavior common to objects
> of a certain kind. A class can be defined in terms of other classes*
>
> *- [Wikipedia](https://en.wikipedia.org/wiki/Class_hierarchy)*

The page also states that class hierarchy (or generally type hierarchy in our case),
is very similar to taxonomy. From a human's point of view is thus quite natural:
an apple is a fruit, which is a vegetable, which is a living entity.

*But programmers are evil...*

> *But what happens when the team starts to create type hierarchies on the services?
> That’s my point, [...], where you should start doubting about your coding skills,
> [...] where you start loosing the grasp on the software’s logics.*

If you're a PHP programmer, how many times have you ever wanted PHP had the possibility
to inherit a class from multiple ones? Oh wait, traits are there for this! And how
many times have you found you were sub-classing a tree of classes that God only knows
what is the mother of them all? This is what happens in (poorly?) structured programs
when you have to add a new functionality on top of another one. But that's fine,
until this kind of hierarchy is *passive* only. You're just adding new data and
new setters and getters. But what happens when the team starts to create type hierarchies
on the services? That's my point, my friend who's still reading, where you should
start doubting about your coding skills. That's the point where you start loosing
the grasp on the software's logics.

Now that's too late, you start thinking about a refactoring, but it's huge and difficult
because even if the input and the final output should be the same, you have to
also change all your "inner" tests to match the deep overhaul of the system, and
for sure your boss won't allocate any time for this task.

But wasn't the OOP designed to avoid, in some sort, *spaghetti code*? How is it
possible that it failed so hard?

Again, it's not OOP that failed, but the people (ab)using it (for lack of time,
juniority, little thinking etc).

### So how can we avoid this bad coding habits?

There are several ways, from static code analysis (but *evil programmers* usually
bypass the rules adding exceptions because of course their architecture is always
perfect for the purpose) to peer review (which I tried to introduce in my team
from time to time with no interest at all, because I think they all thought about
being put under a spotlight every time - yeah still talking about *evil programmers*).

Another solution may be to **avoid using programming languages that let the developer
be so free**.

Not being a go post, I won't list and talk about my new language choice: [golang](https://golang.org).

### Take the decision to stop using your main programming language and force yourself using a new one

The most difficult task, at least for me, is to exit my confort zone and take the
risk to seriously start programming with the language of choice that you really
can't know like the old one, because well... it's not that they're shooting you,
if you decide not to do that, right? But as a self-tought software
engineer, I think this is the most straight way, even if maybe not the easiest one, to learn:
by making mistakes. That's how I started programming back when I was just a teenage
willing to write some logics for videogames. Otherwise you'll probably end up with
thinking about writing in another language, but not doing so, and eventually postpone
it indefinitely.

And this is what I'm going to do: my next big project I'm going to write will be
written in Go. I will for sure slow down the development at the beginning, I'll
have troubles finding Go programmers (or people willing to learn it) in my country,
and probably I'll have to rewrite it some point in the future, but still... I've
started programming in go one year ago, but I think my journey has just began today,
writing this very same post.

*And if you feel like me, you should do the same.*
