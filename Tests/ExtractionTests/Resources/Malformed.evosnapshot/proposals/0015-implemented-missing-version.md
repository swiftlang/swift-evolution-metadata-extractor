# Tuple comparison operators

* Proposal: [SE-0015](0015-implemented-missing-version.md)
* Author: [Lily Ballard](https://github.com/lilyball)
* Review Manager: [Dave Abrahams](https://github.com/dabrahams)
* Status: **Implemented**
* Decision Notes: [Rationale](https://forums.swift.org/t/review-add-a-lazy-flatmap-for-sequences-of-optionals/695/4)
* Implementation: [apple/swift#408](https://github.com/apple/swift/pull/408)

## Introduction

Implement comparison operators on tuples up to some arity.

[Swift Evolution Discussion](https://forums.swift.org/t/proposal-implement-and-for-tuples-where-possible-up-to-some-high-arity/251), [Review](https://forums.swift.org/t/review-add-a-lazy-flatmap-for-sequences-of-optionals/695)

Note: The review was initially started on the wrong thread with the wrong title and subsequently corrected.

## Motivation

It's annoying to try and compare tuples of comparable values and discover that
tuples don't support any of the common comparison operators. There's an
extremely obvious definition of `==` and `!=` for tuples of equatable values,
and a reasonably obvious definition of the ordered comparison operators as well
(lexicographical compare).

Beyond just comparing tuples, being able to compare tuples also makes it easier
to implement comparison operators for tuple-like structs, as the relevant
operator can just compare tuples containing the struct properties.

## Proposed solution

The Swift standard library should provide generic implementations of the
comparison operators for all tuples up to some specific arity. The arity should
be chosen so as to balance convenience (all tuples support this) and code size
(every definition adds to the size of the standard library).

When Swift gains support for conditional conformation to protocols, and if Swift
ever gains support for extending tuples, then the tuples up to the chosen arity
should also be conditionally declared as conforming to `Equatable` and
`Comparable`.

If Swift ever gains support for variadic type parameters, then we should
investigate redefining the operators (and protocol conformance) in terms of
variadic types, assuming there's no serious codesize issues.

## Detailed design

The actual definitions will be generated by gyb. The proposed arity here is 6,
which is large enough for most reasonable tuples (but not as large as I'd
prefer), without having massive code increase. After implementing this proposal
for arity 6, a Ninja-ReleaseAssert build increases codesize for
`libswiftCore.dylib` (for both macosx and iphoneos) by 43.6KiB, which is a
1.4% increase.

The generated definitions look like the following (for arity 3):

```swift
@warn_unused_result
public func == <A: Equatable, B: Equatable, C: Equatable>(lhs: (A,B,C), rhs: (A,B,C)) -> Bool {
  return lhs.0 == rhs.0 && lhs.1 == rhs.1 && lhs.2 == rhs.2
}

@warn_unused_result
public func != <A: Equatable, B: Equatable, C: Equatable>(lhs: (A,B,C), rhs: (A,B,C)) -> Bool {
  return lhs.0 != rhs.0 || lhs.1 != rhs.1 || lhs.2 != rhs.2
}

@warn_unused_result
public func < <A: Comparable, B: Comparable, C: Comparable>(lhs: (A,B,C), rhs: (A,B,C)) -> Bool {
  if lhs.0 != rhs.0 { return lhs.0 < rhs.0 }
  if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
  return lhs.2 < rhs.2
}
@warn_unused_result
public func <= <A: Comparable, B: Comparable, C: Comparable>(lhs: (A,B,C), rhs: (A,B,C)) -> Bool {
  if lhs.0 != rhs.0 { return lhs.0 < rhs.0 }
  if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
  return lhs.2 <= rhs.2
}
@warn_unused_result
public func > <A: Comparable, B: Comparable, C: Comparable>(lhs: (A,B,C), rhs: (A,B,C)) -> Bool {
  if lhs.0 != rhs.0 { return lhs.0 > rhs.0 }
  if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
  return lhs.2 > rhs.2
}
@warn_unused_result
public func >= <A: Comparable, B: Comparable, C: Comparable>(lhs: (A,B,C), rhs: (A,B,C)) -> Bool {
  if lhs.0 != rhs.0 { return lhs.0 > rhs.0 }
  if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
  return lhs.2 >= rhs.2
}
```

## Impact on existing code

No existing code should be affected.

## Alternatives considered

I tested building a Ninja-ReleaseAssert build for tuples up to arity 12, but
that had a 171KiB codesize increase (5.5%). I have not tried any other arities.
