module Jwt(JwtError(..), authenticate, decodeToken, getWithJwt) where

{-| Helper functions for Jwt token authentication.

A Jwt Token comprises 3 elements: a header and footer and the content. This package
includes a function to send an authentication request, a function to read the Content-typeof a token;
and a function to send GET requests with the token attached.

# API functions
@docs authenticate, decodeToken, getWithJwt

# Errors
@docs JwtError
-}

import Base64
import Task exposing (Task)
import Result
import Json.Decode as Json exposing ((:=), Value)
import Http exposing (empty)
import String

{-| The three errors that can emerge are:
 - network errors,
 - issues with processing (e.g. base 64 decoding) the token, and
 - problems decoding the json data within the content of the token

-}
type JwtError
    = HttpError String
    | TokenProcessingError String
    | TokenDecodeError String

{-| decodeToken converts the token content to an Elm record structure.

    decoderToken dec token

In the event of success, decodeToken returns an Elm record structure using the JSON Decoder.

-}
decodeToken : Json.Decoder a -> String -> Result JwtError a
decodeToken dec s =
    case String.split "." s of
        (_ :: b :: _ :: []) ->
            case Base64.decode b of
                Result.Ok s ->
                    case Json.decodeString dec s of
                        Result.Ok x -> Result.Ok x
                        Result.Err e -> Result.Err (TokenDecodeError e)
                Result.Err e -> Result.Err (TokenProcessingError e)
        otherwise -> Result.Err (TokenProcessingError s)

-- TASKS

{-| authenticate is a custom Http POST method that sends a stringified
Json object containing the login credentials. It then extracts the token from the
json response from the server and returns it.

    authenticate
        ("token" := Json.string)
        "http://localhost:5000/auth"
        ("{\"username\":\"" ++ model.uname ++ "\",\"password\":\""++ model.pword ++ "\"}")
            |> Task.map Token
            |> Effects.task
-}
authenticate : Json.Decoder String -> String -> String -> Task never (Result JwtError String)
authenticate packetDecoder url body =
    post' packetDecoder url (Http.string body)            -- Task Http.Error String
        |> Task.mapError (\s -> HttpError (toString s))   -- Task JwtError String
        |> Task.toResult                                  -- Task never (Result JwtError String)

-- Same as Http.post but with useful headers (instead of default [])
post' : Json.Decoder a -> String -> Http.Body -> Task Http.Error a
post' dec url body =
    Http.send Http.defaultSettings
    { verb = "POST"
    , headers = [("Content-type", "application/json")]
    , url = url
    , body = body
    }
        |> Http.fromJson dec

{-| getWithJwt is a replacement for Http.get that also takes a Jwt token and
inserts it in the headers of the GET.

    getWithJwt model.token "http://localhost:5000/api/restos/test"
        |> Task.toResult
        |> Task.map AuthData
        |> Effects.tasks
-}
getWithJwt : String -> Json.Decoder a -> String -> Task Http.Error a
getWithJwt token dec url =
    Http.send Http.defaultSettings
        { verb = "GET"
        , headers = [("Authorization", "Bearer " ++ token)]
        , url = url
        , body = empty
        }
        |> Http.fromJson dec