module Generator exposing
    ( Generator(..)
    , fromList, once, numFrom
    , fromFn, toTuple, fromTuple, groupBy, split
    , filter, filterMap
    , pipe, pipeTo
    , peek, step, collect
    )

{-|


# Generator

@docs Generator


# Source Generators

@docs fromList, once, numFrom


# Transform Generators

@docs fromFn, toTuple, fromTuple, groupBy, split


## Filter

@docs filter, filterMap


# Compose Generators

@docs pipe, pipeTo


# Read data

@docs peek, step, collect

-}


{-|

    numbers : Int -> Generator Never Int
    numbers n =
        Yield n (\_ -> number (n + 1))

-}
type Generator input output
    = Yield output (() -> Generator input output)
    | Step (input -> Generator input output)
    | Done


{-| -}
numFrom : Int -> Generator Never Int
numFrom i =
    Yield i (\_ -> numFrom (i + 1))


{-| -}
toTuple : Generator a ( a, a )
toTuple =
    Step (\x -> Step (\y -> Yield ( x, y ) (\_ -> toTuple)))


{-| -}
fromTuple : Generator ( a, a ) a
fromTuple =
    Step (\( x, y ) -> Yield x (\_ -> Yield y (\_ -> fromTuple)))


{-| -}
fromList : List a -> Generator Never a
fromList list =
    case list of
        [] ->
            Done

        x :: rest ->
            Yield x (\_ -> fromList rest)


{-| -}
filter : (a -> Bool) -> Generator a a
filter fn =
    Step
        (\a ->
            if fn a then
                Yield a (\_ -> filter fn)

            else
                filter fn
        )


{-| -}
filterMap : (a -> Maybe b) -> Generator a b
filterMap fn =
    Step
        (\a ->
            case fn a of
                Just b ->
                    Yield b (\_ -> filterMap fn)

                Nothing ->
                    filterMap fn
        )


{-| -}
once : a -> Generator Never a
once a =
    Yield a (\_ -> Done)


{-| -}
fromFn : (a -> b) -> Generator a b
fromFn fn =
    Step (\a -> Yield (fn a) (\_ -> fromFn fn))


{-| -}
groupBy : Int -> Generator a (List a)
groupBy n =
    groupByHelp n 0 []


groupByHelp : Int -> Int -> List a -> Generator a (List a)
groupByHelp n c st =
    if c >= n then
        Yield (List.reverse st) (\_ -> groupByHelp n 0 [])

    else
        Step (\i -> groupByHelp n (c + 1) (i :: st))


{-| -}
split : Generator (List a) a
split =
    let
        yieldList list =
            case list of
                [] ->
                    split

                x :: xs ->
                    Yield x (\_ -> yieldList xs)
    in
    Step yieldList



--


{-| -}
pipe : Generator input a -> Generator a output -> Generator input output
pipe from to =
    pipeTo to from


{-| -}
pipeTo : Generator a output -> Generator input a -> Generator input output
pipeTo to from =
    case to of
        Yield o nextTo ->
            Yield o (\_ -> pipeTo (nextTo ()) from)

        Step getTo ->
            case from of
                Yield a nextFrom ->
                    pipeTo (getTo a) (nextFrom ())

                Step getFrom ->
                    Step (\i -> pipeTo to (getFrom i))

                Done ->
                    Done

        Done ->
            Done


{-| -}
untilDone : (a -> b -> b) -> b -> Generator Never a -> b
untilDone fn init s =
    init


{-| -}
step : Generator Never a -> ( Maybe a, Generator Never a )
step s =
    case s of
        Yield a next ->
            ( Just a, next () )

        Step fn ->
            ( Nothing, Done )

        Done ->
            ( Nothing, Done )


{-| -}
peek : Generator Never a -> Maybe a
peek s =
    case s of
        Yield a next ->
            Just a

        Step fn ->
            Nothing

        Done ->
            Nothing


{-| -}
collect : Int -> Generator Never a -> List a
collect count nx =
    if count <= 0 then
        []

    else
        case step nx of
            ( Just a, nxx ) ->
                a :: collect (count - 1) nxx

            _ ->
                []


{-| -}



--test : List Int


test =
    numFrom 10
        |> pipeTo (groupBy 5)
        |> collect 5


isEven : Int -> Bool
isEven i =
    modBy 2 i == 0
