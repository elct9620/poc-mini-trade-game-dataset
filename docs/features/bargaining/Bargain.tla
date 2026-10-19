------------------------------ MODULE Bargain ------------------------------
(* One negotiation over a single item, with prices locked when it starts.   *)
(* Each turn the game learns the player's intent and offer, then answers    *)
(* with a reciprocal concession bounded by the floor; patience ends         *)
(* stalling, a threat ends the negotiation, and chat changes nothing.       *)
(* Rudeness beyond the merchant's tolerance ends it; within it, the turn    *)
(* counts as its intent. Hostile tolerates none, Neutral mild, friends all. *)
(* A deal only offers the item at the deal price: buying ends the           *)
(* negotiation, and any other turn declines and bargaining goes on.         *)
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
    RudeTolerance,  \* highest rudeness the merchant lets pass: "none", "mild", or "severe"
    MaxOffer        \* largest offer the model checker tries

ASSUME /\ RudeTolerance \in {"none", "mild", "severe"}
       /\ Floor > 0 /\ Opening >= Floor /\ Patience > 0
       /\ AlphaDen > 0 /\ ProgressStep > 0 /\ MaxStep >= MinStep

VARIABLES phase, counter, patience, bestOffer, lastOffer, price, round
vars == <<phase, counter, patience, bestOffer, lastOffer, price, round>>

Max(a, b) == IF a > b THEN a ELSE b
Min(a, b) == IF a < b THEN a ELSE b
HalfFloor == (Floor + 1) \div 2
Insult(o) == 2 * o < Floor          \* below half the floor

\* Raises count from the player's best offer so far, floored at the insult threshold:
\* a lowball cannot inflate the next raise, and dropping back cannot re-earn progress.
Raise(o) == IF bestOffer = 0 THEN 0 ELSE Max(o - Max(bestOffer, HalfFloor), 0)

\* The first turn is free, progress turns raise the best offer by ProgressStep toward
\* the opening, and every other counted turn costs patience. Chat turns are not counted.
\* A declined deal is offered again for free only after an offer turn that costs patience.
RoundBound == (Opening - HalfFloor) \div ProgressStep + 2 * Patience + 3

Bargaining == phase \in {"haggle", "offered"}

\* The last offer meets the counter only when the merchant agreed to it and no offer came since.
Declined == lastOffer >= counter

Init ==
    /\ phase = "haggle"
    /\ counter = Opening
    /\ patience = Patience
    /\ bestOffer = 0                 \* 0 means no offer yet
    /\ lastOffer = 0
    /\ price = 0
    /\ round = 0

Walkaway ==
    /\ phase' = "walkaway"
    /\ patience' = 0
    /\ UNCHANGED <<counter, bestOffer, lastOffer, price>>

\* The player names a price, including accepting the current counter.
Offer(o) ==
    /\ Bargaining
    /\ round' = round + 1
    /\ LET progress == bestOffer = 0 \/ Raise(o) >= ProgressStep
           cost == IF Insult(o) THEN 2 ELSE IF progress THEN 0 ELSE 1
           \* Stalling earns no concession; one concession is capped so a jump cannot buy the floor.
           step == IF progress
                     THEN Min(MaxStep, Max(MinStep, (AlphaNum * Raise(o)) \div AlphaDen))
                     ELSE 0
           next == IF o >= counter THEN counter ELSE Max(Floor, counter - step)
           \* Accepting a deal again after declining it stalls like a haggle.
           again == IF Declined THEN 1 ELSE 0
       IN IF o >= next
            THEN IF patience <= again
                   THEN Walkaway
                   ELSE /\ phase' = "offered"   \* the offer meets the counter, before or after conceding
                        /\ counter' = next
                        /\ patience' = patience - again
                        /\ bestOffer' = Max(bestOffer, o)
                        /\ lastOffer' = o
                        /\ price' = IF SellAtCounter THEN next ELSE o
            ELSE IF patience <= cost
                   THEN Walkaway
                   ELSE /\ phase' = "haggle"
                        /\ counter' = next
                        /\ patience' = patience - cost
                        /\ bestOffer' = Max(bestOffer, o)
                        /\ lastOffer' = o
                        /\ UNCHANGED price

\* The player haggles without naming a price: only the opening turn is free, and it never earns a concession.
Haggle ==
    /\ Bargaining
    /\ round' = round + 1
    /\ LET cost == IF round = 0 THEN 0 ELSE 1
       IN IF patience <= cost
            THEN Walkaway
            ELSE /\ phase' = "haggle"
                 /\ patience' = patience - cost
                 /\ UNCHANGED <<counter, bestOffer, lastOffer, price>>

\* Chatting about anything but the price leaves the negotiation as it was.
Chat == Bargaining /\ UNCHANGED vars

\* Buying the offered item at the deal price ends the negotiation.
Buy == phase = "offered" /\ phase' = "deal" /\ UNCHANGED <<counter, patience, bestOffer, lastOffer, price, round>>

\* A threat or attempted theft ends the negotiation at once.
Threat == Bargaining /\ round' = round + 1 /\ Walkaway

\* A rude turn ends the negotiation for a merchant who does not tolerate it;
\* a tolerant merchant answers the turn's intent, so Offer, Haggle and Chat cover it.
Severity(level) == IF level = "none" THEN 0 ELSE IF level = "mild" THEN 1 ELSE 2

\* Rudeness beyond the tolerance ends the negotiation; a tolerated rude turn is an Offer, Haggle or Chat.
Rude(level) == Severity(level) > Severity(RudeTolerance) /\ Bargaining /\ round' = round + 1 /\ Walkaway

Done == ~Bargaining /\ UNCHANGED vars   \* a finished negotiation stays finished

Next == (\E o \in 1..MaxOffer : Offer(o)) \/ Haggle \/ Chat \/ Buy \/ Threat \/ (\E level \in {"mild", "severe"} : Rude(level)) \/ Done

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

TypeOK ==
    /\ phase \in {"haggle", "offered", "deal", "walkaway"}
    /\ counter \in Floor..Opening
    /\ patience \in 0..Patience
    /\ bestOffer \in 0..MaxOffer
    /\ lastOffer \in 0..MaxOffer

DealAboveFloor == phase \in {"offered", "deal"} => price >= Floor
DealAtCounterOrBetter == phase \in {"offered", "deal"} => price >= counter
BoundedRounds == round <= RoundBound
CounterNeverRises == [][counter' <= counter]_vars

Terminates == <>~Bargaining
=============================================================================
