Encase
======

Encase is a Ruby library for improving your code through judicious application of method decorators.  This allows you to leverage powerful dynamic type checking, multiple dispatch, flow-control annotations, and any custom safeties you can create on your own.

Usage
-----

## Contracts

Contracts allow you to describe the signature of your method, which can then be automatically tested at runtime.

``` ruby
Contract String, String => String
def concat(x, y)
  x + y
end

concat('1', '2')  # => '12'

concat(1, 2)  # => Exception!
```

A number of built-in helper types are also included.

``` ruby
Contract Pos => Bool
def greater_than_three(x)
  x > 3
end
```

Technically, almost anything that can be compared with the `===` operator can be used in a contract, making it easy to specify robust signatures and extend the type system to meet your needs.

``` ruby
Contract /^-?\d+$/ => Num
def coerce_to_int(str)
  str.to_i(10)
end
```
