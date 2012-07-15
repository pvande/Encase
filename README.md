Encase
======

        There was a look of sheer panic in the dame's eye as she pulled her
      clutch to her chest.  I'd seen it a thousand times before, and she was
      right to be afraid - the things in her purse could easily pay the rent
      on my dingy little office for a couple of years.  A Decorator of about
      thirty, she'd clearly never considered the threats inherent to the real
      world - not every gentleman Caller had good intentions.  Gently, I
      explained how she might protect it, wrapping it in layers security.
      Cocooning it.    Encasing it.
        At length, she handed the purse over, and I breathed a sigh of relief.
      Unprotected valuables make me nervous.  That's why I took this job.  I
      make things safe.

Encase is an library of extensible library of method decorators, primarily focussed on promoting and improving the discovery of bugs.  The first step towards this end is implementing a robust type-checking system, to automatically validate the inputs and outputs of each method call - this is implimented via the Contract decorator.

Installation
------------

    $ cd vendor
    $ git clone git://github.com/pvande/encase.git

Usage
-----

### Contracts

Contracts give you a way to express explicit type validations on your Ruby
methods. This makes the expectations around your code much more clear, and
helps (with the aid of robust unit tests) provide guarantees about the type
safety of your code.

Getting started is easy:

    class StrictTyping
      include Encase::Contracts

      Contract Integer, Returns[Integer]
      def double(n)
        n * 2
      end
    end

The special type `Returns` can be used to express type constraints around the
return value of the method.  Because this is such a common use case, there is
a shorthand for expressing that constraint.

    Contract Integer => Integer
    def double(n)
      n * 2
    end

This is a familiar system of constraints to those who've used C, Java, or
Haskell before, but part of Ruby's strength comes from duck typing. In that
spirit, we can write contracts that validate not only classes but any object
that supports Ruby's case equality operator (i.e. `===`)

    Contract /^\d+$/ => Integer
    def int(str)
      str.to_i(10)
    end

Contracts are capable of much more, including validating the signature of
blocks (and other procs!), destructuring arrays and hashes, typechecking
splatted arguments, checking logical conjunctions of types and more!

Contracts also offer two callbacks, executed after each constraint validation,
which can be overridden to better fit the environment your application runs
in.

    class Encase::Contract
      # Exceptions are too harsh in Production; maybe we'll just add a message
      # to the logfile...
      def failure(data)
        Logger.log_error("Failed Validation: " + data.inspect)
        return true
      end
    end

In Production?
--------------

Some of the included decorators may impart a non-trivial runtime performance
penalty which may be undesirable in a production environment. For those cases,
every decorator class includes a `disable` method which will cause all
instances of that class (and all subclasses) to bypass all non-critical
behavior.

Similarly, some decorators include explicit extension points, making it easy
to redefine the behavior of the decorator to be better suited to your
production environment.

Copyright
---------

Copyright (c) 2012 Pieter van de Bruggen.

(The GIFT License, v3)

Permission is hereby granted to use this software and/or its source code for
whatever purpose you should choose. Seriously, go nuts. Use it for your pet
open-source project, your "financial independence" webapp, or your distributed
financial databases.

I don't care, it's yours. Change the name on it if you want -- in fact, if you
start significantly changing what it does, I'd rather you did! Make it your
own little work of art, complete with a stylish flowing signature in the
corner. All I really did was give you the canvas. And my blessing.

    Know always right from wrong, and let others see your good works.
