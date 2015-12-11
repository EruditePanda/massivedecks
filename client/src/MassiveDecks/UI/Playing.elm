module MassiveDecks.UI.Playing where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)

import MassiveDecks.Models.State exposing (PlayingData, Error, Global)
import MassiveDecks.Models.Card as Card
import MassiveDecks.Models.Player exposing (Player, Id, Status(..))
import MassiveDecks.Models.Game exposing (Round)
import MassiveDecks.Models.Card exposing (Response, Responses(..), PlayedCards)
import MassiveDecks.Actions.Action exposing (Action(..), APICall(..))
import MassiveDecks.UI.Lobby as LobbyUI
import MassiveDecks.UI.General exposing (..)
import MassiveDecks.Util as Util


view : Signal.Address Action -> Global -> PlayingData -> Html
view address global data =
  let
    errors = global.errors
    lobby = data.lobby
    (content, header) =
      case data.lastFinishedRound of
        Just round -> winnerContentsAndHeader address round lobby.players
        Nothing ->
          case lobby.round of
            Just round ->
              (roundContents address data round,
                [ icon "gavel", text (" " ++ (czarName lobby.players round.czar)) ])
            Nothing -> ([], [])
  in
    LobbyUI.view global.initialState.url data.lobby.id header lobby.players (List.concat [ content, [ errorMessages address errors ] ])


roundContents : Signal.Address Action -> PlayingData -> Round -> List Html
roundContents address data round =
  let
    hand = data.hand.hand
    pickedWithIndex = Util.getAllWithIndex hand data.picked
    picked = List.map snd pickedWithIndex
    id = data.secret.id
    isCzar = round.czar == id
    hasPlayed = List.filter (\player -> player.id == id) data.lobby.players
      |> List.any (\player -> player.status == Played)
    pickedOrPlayed = case round.responses of
      Revealed responses -> [ playedView address isCzar responses ]
      Hidden _ -> pickedView address pickedWithIndex (Card.slots round.call) data.shownPlayed
  in
    [ playArea
      [ div [ class "round-area" ] (List.concat [ [ call round.call picked ], pickedOrPlayed ])
      , handView address data.picked (isCzar || hasPlayed) hand
      ]
    ]


winnerContentsAndHeader : Signal.Address Action -> Round -> List Player -> (List Html, List Html)
winnerContentsAndHeader address round players =
  let
    winning = case round.responses of
      Revealed revealed ->
          (Card.winningCards revealed.cards)
          |> Maybe.andThen revealed.playedByAndWinner
          |> Maybe.withDefault []
      Hidden _ -> []
    winner = case round.responses of
      Revealed revealed ->
          revealed.playedByAndWinner
          |> Maybe.map .winner
          |> Maybe.map (Util.get players)
          |> Maybe.map .name
          |> Maybe.withDefault ""
      Hidden _ -> ""
  in
    ([ div [ class "winner mui-panel" ]
       [ h1 [] [ icon "trophy" ]
       , h2 [] [ text (" " ++ Card.filled round.call winning) ]
       , h3 [] [ text ("- " ++ winner) ]
       ]
     , button [ id "next-round-button", class "mui-btn mui-btn--primary mui-btn--raised", onClick address NextRound ]
         [ text "Next Round" ]
     ], [ icon "trophy", text (" " ++ winner) ])


czarName : List Player -> Id -> String
czarName players czarId =
  (List.filter (\player -> player.id == czarId) players) |> List.head |> Maybe.map .name |> Maybe.withDefault ""


playArea : List Html -> Html
playArea contents = div [ class "play-area" ] contents


call : List String -> List Response -> Html
call contents picked = div [ class "card call mui-panel" ]
                    [ div [ class "call-text "] (Util.interleave (slots (Card.slots contents) "" picked) (List.map text contents)) ]


slot : String -> Html
slot value = (span [ class "slot" ] [ text value ])


slots : Int -> String -> List Response -> List Html
slots count placeholder picked =
  let
    extra = count - List.length picked
  in
    List.concat [picked, List.repeat extra placeholder] |> List.map slot


response : Signal.Address Action -> List Int -> Bool -> Int -> String -> Html
response address picked disabled responseId contents =
  let
    isPicked = List.member responseId picked
    pickedClass = if isPicked then " picked" else ""
    classes = [ class ("card response mui-panel" ++ pickedClass) ]
    clickHandler = if isPicked || disabled then [] else [ onClick address (Pick responseId) ]
  in
    div (List.concat [ classes, clickHandler ]) [ div [ class "response-text" ] [ text contents ] ]


blankResponse : Attribute -> Html
blankResponse positioning = div [ class "card mui-panel", positioning ] []


handRender : Bool -> List Html -> Html
handRender disabled contents =
  let
    classes = "hand mui--divider-top" ++ if disabled then " disabled" else ""
  in
    ul [ class classes ] (List.map (\item -> li [] [ item ]) contents)


handView : Signal.Address Action -> List Int -> Bool -> List Response -> Html
handView address picked disabled responses = handRender disabled (List.indexedMap (response address picked disabled) responses)


pickedResponse : Signal.Address Action -> (Int, String) -> Html
pickedResponse address (index, contents) =
  li [ onClick address (Withdraw index) ] [ div [ class "card response mui-panel" ] [ div [ class "response-text" ] [ text contents ] ] ]


pickedView : Signal.Address Action -> List (Int, Response) -> Int -> List Attribute -> List Html
pickedView address picked slots shownPlayed =
  let
    pb = if (List.length picked < slots) then [] else [ playButton address ]
  in
    [ ol [ class "picked" ] (List.concat [ (List.map (pickedResponse address) picked), pb ])
    , div [ class "others-picked" ] (List.map blankResponse shownPlayed)
    ]


playButton : Signal.Address Action -> Html
playButton address = li [ class "play-button" ] [ button
  [ class "mui-btn mui-btn--small mui-btn--accent mui-btn--fab", onClick address (Play Request) ]
  [ icon "thumbs-up" ] ]


playedView : Signal.Address Action -> Bool -> Card.RevealedResponses -> Html
playedView address isCzar responses =
  ol [ class "played" ] (List.indexedMap (\index pc -> li [] [ (playedCards address isCzar index pc) ]) responses.cards)


playedCards : Signal.Address Action -> Bool -> Int -> PlayedCards -> Html
playedCards address isCzar playedId cards =
  let
    extra = if isCzar then [ chooseButton address playedId ] else []
  in
    ol [] (List.concat [ (List.map (\card -> li [] [ (playedResponse card) ]) cards), extra ])


playedResponse : Response -> Html
playedResponse contents =
  div [ class "card response mui-panel" ] [ div [ class "response-text" ] [ text contents ] ]


chooseButton : Signal.Address Action -> Int -> Html
chooseButton address playedId = li [ class "choose-button" ] [ button
  [ class "mui-btn mui-btn--small mui-btn--accent mui-btn--fab", onClick address (Choose playedId Request) ]
  [ icon "trophy" ] ]
