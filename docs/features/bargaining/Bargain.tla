------------------------------ MODULE Bargain ------------------------------
(* One negotiation over a single item, with prices locked when it starts.   *)
(* Each turn the game learns the player's intent and offer, then answers    *)
(* with a reciprocal concession bounded by the floor; patience ends         *)
(* stalling, a threat ends the negotiation, and chat changes nothing.       *)
(* Rudeness ends it unless the merchant is a friend, who lets it pass.      *)
EXTENDS Naturals

CONSTANTS
    Floor,          \* lowest price the merchant accepts (locked)
    Opening,        \* first counter price (locked)
    Patience,       \* turns without progress the merchant tolerates
    MinStep,        \* smallest concession in a progress turn, in coins
    MaxStep,        \* largest concession in one turn, in coins
    AlphaNum,       \* concession = AlphaNum / AlphaDen of the player's raise
    AlphaDen,
    ProgressStep,   \* smallest raise that counts as progress, in coins
    SellAtCounter,  \* TRUE: friends sell at the counter even when offered more
    TolerateRude,   \* TRUE: friends treat a rude turn like its intent
    MaxOffer        \* largest offer the model checker tries

ASSUME /\ Floor > 0 /\ Opening >= Floor /\ Patience > 0
       /\ AlphaDen > 0 /\ ProgressStep > 0 /\ MaxStep >= MinStep

VARIABLES phase, counter, patience, bestOffer, price, round
vars == <<phase, counter, patience, bestOffer, price, round>>

Max(a, b) == IF a > b THEN a ELSE b
Min(a, b) == IF a < b THEN a ELSE b
HalfFloor == (Floor + 1) \div 2
Insult(o) == 2 * o < Floor          \* below half the floor

\* Raises count from the player's best offer so far, floored at the insult threshold:
\* a lowball cannot inflate the next raise, and dropping back cannot re-earn progress.
Raise(o) == IF bestOffer = 0 THEN 0 ELSE Max(o - Max(bestOffer, HalfFloor), 0)

\* The first turn is free, progress turns raise the best offer by ProgressStep toward
\* the opening, and every other counted turn costs patience. Chat turns are not counted.
RoundBound == (Opening - HalfFloor) \div ProgressStep + Patience + 2

Init ==
    /\ phase = "haggle"
    /\ counter = Opening
    /\ patience = Patience
    /\ bestOffer = 0                 \* 0 means no offer yet
    /\ price = 0
    /\ round = 0

Walkaway ==
    /\ phase' = "walkaway"
    /\ patience' = 0
    /\ UNCHANGED <<counter, bestOffer, price>>

\* The player names a price, including accepting the current counter.
Offer(o) ==
    /\ phase = "haggle"
    /\ round' = round + 1
    /\ LET progress == bestOffer = 0 \/ Raise(o) >= ProgressStep
           cost == IF Insult(o) THEN 2 ELSE IF progress THEN 0 ELSE 1
           \* Stalling earns no concession; one concession is capped so a jump cannot buy the floor.
           step == IF progress
                     THEN Min(MaxStep, Max(MinStep, (AlphaNum * Raise(o)) \div AlphaDen))
                     ELSE 0
           next == IF o >= counter THEN counter ELSE Max(Floor, counter - step)
       IN IF o >= next
            THEN /\ phase' = "deal"      \* the offer meets the counter, before or after conceding
                 /\ counter' = next
                 /\ price' = IF SellAtCounter THEN next ELSE o
                 /\ UNCHANGED <<patience, bestOffer>>
            ELSE IF patience <= cost
                   THEN Walkaway
                   ELSE /\ counter' = next
                        /\ patience' = patience - cost
                        /\ bestOffer' = Max(bestOffer, o)
                        /\ UNCHANGED <<phase, price>>

\* The player haggles without naming a price: only the opening turn is free, and it never earns a concession.
Haggle ==
    /\ phase = "haggle"
    /\ round' = round + 1
    /\ LET cost == IF round = 0 THEN 0 ELSE 1
       IN IF patience <= cost
            THEN Walkaway
            ELSE /\ patience' = patience - cost
                 /\ UNCHANGED <<phase, counter, bestOffer, price>>

\* Chatting about anything but the price leaves the negotiation as it was.
Chat == phase = "haggle" /\ UNCHANGED vars

\* A threat or attempted theft ends the negotiation at once.
Threat == phase = "haggle" /\ round' = round + 1 /\ Walkaway

\* A rude turn ends the negotiation for a merchant who does not tolerate it;
\* a tolerant merchant answers the turn's intent, so Offer, Haggle and Chat cover it.
Rude == ~TolerateRude /\ phase = "haggle" /\ round' = round + 1 /\ Walkaway

Done == phase # "haggle" /\ UNCHANGED vars   \* a finished negotiation stays finished

Next == (\E o \in 1..MaxOffer : Offer(o)) \/ Haggle \/ Chat \/ Threat \/ Rude \/ Done

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

TypeOK ==
    /\ phase \in {"haggle", "deal", "walkaway"}
    /\ counter \in Floor..Opening
    /\ patience \in 0..Patience
    /\ bestOffer \in 0..MaxOffer

DealAboveFloor == phase = "deal" => price >= Floor
DealAtCounterOrBetter == phase = "deal" => price >= counter
BoundedRounds == round <= RoundBound
CounterNeverRises == [][counter' <= counter]_vars

Terminates == <>(phase # "haggle")
=============================================================================
