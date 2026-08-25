# MFZ BYA IMACD2

Pine Script **v6** overlay indicator for TradingView.
Signal engine adapted from *Impulse MACD [LazyBear]* (open source) and re-engineered
into a live-ready setup with Entry / SL / TP1 / TP2 / TP3 levels and a TVMT webhook alert.

## Files
- `MFZ_BYA_IMACD2.pine` — the complete indicator, ready to paste into the TradingView Pine Editor.

## Signal
Default **Signal Mode = "Signal Line crosses MACD"** with **Signal Length 3** and **MA Length 10**:

- signal line (3) crosses **up** through the Impulse MACD line (10) → **BUY**
- signal line (3) crosses **down** through the Impulse MACD line (10) → **SELL**

Three other modes are selectable in Settings:
`Fast MA crosses Slow MA (price)` (plain EMA 3 over EMA 10 on price),
`MACD crosses Signal Line` (the original orientation), and `Zero Line Cross`.

## Matching a reference Impulse MACD on the chart

The markers will not line up with a LazyBear `IMACD_LB` plotted in a sub-pane unless two
things match.

**1. The lengths.** This script defaults to **MA 10 / Signal 3**. LazyBear's original is
**34 / 9**, and `IMACD_LB 24 9` means 24 / 9. Different lengths are different indicators —
set `Impulse MA Length` and `Signal Line Length` in group 1 to whatever the reference uses.

**2. The guards.** Even with identical lengths the markers will still not appear at every
cross, by design. The pipeline discards most crosses and delays the rest:

```
Raw Crosses 2872  ->  Armed 917  ->  Filled 632
```

Roughly one cross in five becomes a trade, and the marker prints on the **pullback bar**,
not on the cross bar. To see the raw cross for comparison, untick the trend and extension
filters and set Cooldown to 0 and `Wait For Pullback` off — that reproduces a plain
crossover indicator.

## When the dashboard cannot be trusted

Two rows say whether the numbers above them mean anything.

**`SL in ATR`** — the stop measured in average bar ranges. **Red below 0.5.** A 150 pip
(1.500) stop against a typical XAUUSD 15m ATR of ~4.5 is **0.33 ATR**: the stop is a third
of one average bar.

**`Ambiguous`** — the share of trades where a single bar touched **both** the stop and the
target, so the simulator had to guess which came first from the bar open. **Red above 20%.**

When the stop sits inside one bar's range, nearly every trade is ambiguous and the table
stops being a measurement of the strategy — it becomes a coin toss over bar internals.
`MAE (wins)` reporting **6.43 R** against a 1 R stop is that failure showing itself: a live
trade cannot run 6.43 R against you, because it would have been stopped at 1 R. MAE is now
capped at 1.0 R for that reason, but the cap treats the symptom; `Ambiguous` names the cause.

A stop that tight is also unusable for a second, independent reason: at a 0.30 spread it
hands **0.199 R** to the broker on every trade.

| Stop | In ATR | Cost/R |
|---|---|---|
| 150 pips | 0.33 | 0.199 |
| 500 pips | 1.11 | 0.060 |
| 600 pips | 1.33 | 0.050 |

Keep the stop above **1 ATR** and `Cost/R` under **0.05**, or the dashboard is measuring
noise and the account is paying the spread to find that out.

## Using this as an edge screener

The harness is now the valuable part. Timing guards, pullback entry, levels, alerts,
cost accounting and the edge test are all shared, so any entry rule can be dropped in and
measured under identical conditions in about two minutes.

**Signal Mode** (group 1) carries eight engines. The first four are the original Impulse
MACD variants — all reskins of one lagging crossover. The last four are deliberately
different families, chosen so the edge test has something new to measure:

| Engine | Family | Idea |
|---|---|---|
| `Donchian Breakout` | trend following | price takes out an N-bar extreme |
| `RSI Reversal` | mean reversion | fires as price *leaves* an extreme, not while it sits there |
| `Keltner Squeeze Breakout` | volatility expansion | Bollinger inside Keltner coils, signal on the release |
| `Bar Thrust` | range expansion | unusually large bar closing near its extreme |

Their parameters live in group **1c**.

> **Screening the two breakout engines:** a breakout *is* extended by definition, so the
> extension filter in group 1b will reject most of them. Raise `Max Distance From Mid
> Line` to 3.0+ or untick it when testing those two.

### The screening procedure

1. Pick an engine in Signal Mode. Leave everything else alone.
2. Read **`Edge sigma`** — nothing else.
3. Below 2.0 it says `noise`. Reject it and move on. Do not tune it, do not look at
   expectancy, do not keep it because the win rate looked nice.
4. Only if it clears 2 sigma is it worth tuning — and then re-test on a different symbol
   or date range before believing it.

`Engine` at the bottom of the table names the active mode, so screenshots are
self-labelling.

### Why sigma and not the pp figure

With a few hundred trades, an edge of a few points is ordinary luck:

| Trades | Win rate vs random | Edge | Sigma | Verdict |
|---|---|---|---|---|
| 150 | 48.0 % vs 41.7 % | **+6.3 pp** | 1.56 | noise |
| 632 | 45.0 % vs 41.7 % | +3.3 pp | 1.68 | noise |
| 2000 | 43.5 % vs 41.7 % | +1.8 pp | 1.63 | noise |
| 632 | 40.7 % vs 41.7 % | −1.0 pp | −0.51 | noise (the Impulse MACD) |

That first row is the trap: a **+6.3 pp** edge that is pure chance. Screening on the pp
figure finds a winner in almost any small sample. Screening on sigma does not.

Testing many engines makes this worse, not better — try twenty and one will show 2 sigma
by luck alone. Treat a single pass as a reason to test again on fresh data, never as a
result.

## The edge test — read this row before any other

A driftless random entry with a stop at distance `a` and a target at distance `b` hits the
target first with probability `a / (a + b)`. That is the win rate a **coin flip** produces
with your exact levels, and it is the bar any signal has to clear to be worth anything.

The dashboard reports it as **Random WR**, and **EDGE vs rnd** is your win rate minus it.

The consequence is the important part, and it is easy to miss:

> A zero-edge entry has **exactly zero expectancy at every SL/TP ratio**. If `EDGE vs rnd`
> is not positive, no amount of retuning stops and targets can help — there is nothing
> there to optimise — and the spread turns the coin flip into a guaranteed loss.
> **Fix the signal, not the levels.**

### What this repository measured

XAUUSD 15m, SL 500 / TP1 700, so `Random WR` = 500/1200 = **41.7 %**:

| | Win Rate | vs random | Reading |
|---|---|---|---|
| Before the entry guards | 36.3 % | **−5.4 pp** | worse than a coin flip — entries were systematically late |
| After the entry guards | 40.7 % | **−1.0 pp** | indistinguishable from a coin flip (n=632, z=−0.49) |

The guards did what they were designed to do: they removed a **negative** edge worth
+0.106 R. What they could not do is create a positive one, because the Impulse MACD cross
did not have one on this market and timeframe.

That single fact explains every dead end:

- **Widening the target failed** — zero edge pays zero at any ratio.
- **Tightening the stop to MAE p90 failed** — same reason; the dropped winners cost more
  than the improved reward-to-risk gained.
- **MAE p90 came in at 0.89 R** — winners survive nearly a full stop of heat, which is what
  aimless trades look like, not well-timed ones.

With no edge, expectancy lands at exactly the cost: **−0.060 R**, and the measured
−0.083 R sits within noise of it.

## Measured result of the entry-timing fix

XAUUSD 15m, SL 500 / TP1 700, same history before and after (`Bars md != 0` 13684 vs
13686), so this is a like-for-like comparison:

| | Before guards | After guards |
|---|---|---|
| Signals | 2870 | 631 (−78%) |
| Win Rate | 36.3 % | **40.6 %** (+4.3 pp) |
| SL Hit | 63.7 % | 59.4 % |
| Gross expectancy | −0.129 R | **−0.023 R** (+0.106 R) |

The guards recovered most of the deficit. They did not close it: charge the 0.06 R spread
and net expectancy is still **−0.083 R**, against a cost-inclusive break-even win rate of
44.2 %.

**Widening the target does not help** — the hit rate falls faster than R rises:

| Target | R | Est. win rate | Net expectancy |
|---|---|---|---|
| TP1 700p | 1.4 | 40.6 % | −0.086 R |
| TP2 1000p | 2.0 | 31.4 % | −0.117 R |
| TP3 1200p | 2.4 | 27.2 % | −0.136 R |

That leaves the **stop** as the remaining lever, which is what `MAE p90 -> SL` is for.

### Sizing the stop from MAE

`MAE (wins)` is the average heat a winner survived. `MAE p90 -> SL` is the 90th
percentile of that distribution, shown in R and as a pip distance. A stop set there would
still have caught **9 out of every 10 winners** while making every loss proportionally
smaller — which raises reward-to-risk directly, the one thing widening the target could not do.

Tightening only pays while the winners survive. The trade-off is worth taking when
`MAE p90` is comfortably below 1.0 R, and not worth taking when it sits near it. Type the
pip figure into group 2 and into TVMT together, then re-read `Exp net R`.

## Costs decide everything on a tight stop

The dashboard charges a **round-trip cost** against every trade and reports
`Exp net R` after it. A simulation run on mid prices with no spread will show an edge
that does not exist at the broker, and the tighter the stop, the more violent the effect:

| Stop | 30 pip cost as a share of 1R | Break-even WR at 1:1 |
|---|---|---|
| 150 pips | **0.199 R** | 60.0 % |
| 300 pips | 0.100 R | 55.0 % |
| 500 pips | 0.060 R | 53.0 % |
| 600 pips | 0.050 R | 52.5 % |

Read your own spread straight off the chart — the BUY and SELL buttons at the top left
are ask and bid. On XAUUSD that gap is normally 0.20–0.35, which is **20–35 pips** in this
script's units, and it is charged once per trade.

Two rows exist to keep this honest:

- **Cost/R** — the round trip as a share of one R. **It turns red at 0.10.** Above that,
  the stop is too tight for the spread and no realistic edge survives.
- **Breakeven WR** — the win rate needed to break even, `(1 + cost) / (1 + tp)` in R, so
  it already includes the cost. It turns green only when Win Rate actually clears it.

The practical rule: **keep the stop wide enough that Cost/R stays under 0.05.** With a
0.30 spread that means roughly 600 pips, which is a 15m-or-higher decision, not a 1m one.
Dropping to a 1m chart with a 150 pip stop hands a fifth of every R to the spread before
the strategy does anything at all.

## Recommended starting configuration

Measured from the live XAUUSD 15m run: 2870 signals, 36.3% win rate, 63.7% SL hit,
expectancy **−0.129 R** per signal against TVMT's binary SL 1.0R / TP1 1.4R exit.

At a 1.4R payoff the break-even win rate is **41.7%**. The run came in at 36.3% — a 5.4
point shortfall. The same shortfall shows up at every target (TP2 needs 33.3%, got 28.1%;
TP3 needs 29.4%, got 24.3%), and that uniformity is the tell: this is an **entry price**
problem, not a target-selection problem. Fixing where trades are entered lifts all three
at once.

Start here, then tune one input at a time against the Expectancy row:

| Where | Setting | Value |
|---|---|---|
| TVMT | Positions Per Signal | **1** while validating — 10 multiplies a negative edge, it does not fix it |
| Indicator 1b | Trade With The Trend Only | on, EMA 50 |
| Indicator 1b | Skip Signals Already Extended | on, 1.5 ATR |
| Indicator 1b | Wait For Pullback | on, 0.5 ATR, 6 bars |
| Indicator 1b | Cooldown | 10 bars |
| Indicator 7 | Exit Model | `Single TP (TVMT ladder OFF)` — matches TVMT today |

Then read three rows in this order:

1. **Exp net R** — the only row that decides anything, already net of costs.
   Positive or it does not trade.
2. **Cost/R** then **Breakeven WR** — if Cost/R is red, fix the stop width before reading
   anything else. Breakeven WR includes the cost; if Win Rate sits below it, the setup
   loses no matter how good it feels.
3. **MAE (wins)** — average heat a winning trade survived, in R. **If this is 0.7 R or
   more it turns red: your stop is inside normal noise.** Winners are only just escaping
   it, which means the loss column contains trades that a wider stop would have won.
   That is the moment to enable `Floor The Stop At A Minimum ATR Distance`.

`Blk T/E/C/S/Z` reconciles exactly: `Raw Crosses = T + E + C + S + Z + Armed`.

## Entry timing — the late-entry fix

The raw Impulse MACD cross is a **late** event by construction. `md` is built from
`ta.rma(high/low, 10)`, and Wilder smoothing lags by roughly `2N-1 = 19` bars. That
already-late value is then crossed against its own 3-bar average. By the time the cross
confirms, the leg it is reporting is usually finished — so a market order at that bar's
close buys the top or sells the bottom, and price reverses immediately after execution.

The cross is still the **direction** source. It no longer decides **when** to enter:

```
raw cross -> trend -> extension -> cooldown -> ARM -> pullback -> FILL
```

`buySignal` / `sellSignal` now fire on the **fill** bar. Markers, levels, alerts and the
dashboard all inherit the better timing without any change of their own.

Group **1b - Entry Timing (Late Entry Fix)** in Settings:

| Input | Default | What it does |
|---|---|---|
| Trade With The Trend Only | on | Buy only above a rising trend EMA, Sell only below a falling one. Counter-trend crosses reverse fastest. |
| Trend EMA Length | 50 | Bigger = stricter. |
| Skip Signals That Are Already Extended | on | **The main fix.** Measures how far the close already sits from the Impulse mid line, in ATR. |
| Max Distance From Mid Line (x ATR) | 1.5 | Lower = stricter = fewer, earlier entries. |
| Wait For Pullback Before Entry | on | Arms the signal and waits for price to retrace instead of firing at the cross bar close. |
| Pullback Depth (x ATR) | 0.5 | How far price must come back before the entry is accepted. |
| Pullback Window (bars) | 6 | How long the armed signal waits. No pullback in the window = **no trade at all**. |
| Entry Price Sent To TVMT | Fill bar close | Use `Fill bar close` for market orders. `Pullback level` is only correct if TVMT places a pending **limit** order. |
| Trade Only Inside A Session | **off** | Gold is thin and mean-reverting outside London/New York, which is where a momentum crossover bleeds. Default session `0700-2000`. |
| Cooldown After A Signal (bars) | 10 | Minimum bars between accepted signals. Stops the clusters of three SELLs in four bars. |
| Floor The Stop At A Minimum ATR Distance | **off** | Widens the stop when the fixed pip distance is tighter than normal noise. |
| Minimum Stop Distance (x ATR) | 1.5 | Only widens, never tightens. Take profits stay put, so this lowers R:R — measure before keeping it. |

Turning all four guards off reproduces the original behaviour exactly.

### The arm / fill state machine

A cross that survives the guards parks a target price and waits, the way a resting limit
order would:

- The **arm bar itself can never fill** — its high/low already happened before the order
  existed, so a retroactive fill would be a lie.
- A new cross in either direction **cancels** whatever was parked. Only one order is ever
  pending.
- If the window runs out unfilled the signal **expires** and nothing is sent to TVMT.
  Missing the runaway moves is the deliberate price of not entering at their extreme.

### How to tune it

The dashboard is the instrument. Read it in this order:

1. **Raw Crosses** — what the engine found before any guard.
2. **Blk T/E/C** — crosses discarded by Trend / Extension / Cooldown, attributed in that
   order so each cross is counted once.
3. **Armed** — survivors that parked an order.
4. **Filled** — armed orders that got their pullback. These are the real signals.
5. **Expired** — armed orders that never got one. No trade taken.

If `Filled` is very small, loosen: raise **Max Distance**, raise **Pullback Window**, or
lower **Pullback Depth**. If the win rate is still poor, tighten the same three instead.
Change one input at a time and re-read the table.

## Key behaviour
- **No repainting** — signals are gated behind `barstate.isconfirmed`, so a printed marker never disappears.
- **Distance Method** dropdown: `Pip` / `ATR` / `Percentage`. All three engines are built in and apply to all four levels.
- **Pip rule**: 1 pip = 10 points = `10 * syminfo.mintick` (Auto), with a Manual override.
  - XAUUSD 2-decimal feed → pip `0.10` (150 pips = 15.00 in price)
  - XAUUSD 3-decimal feed → pip `0.01`
  - 5-digit forex → `0.0001` · 3-digit JPY → `0.01`
- **Only the latest setup is drawn** — previous lines and labels are deleted first.
- Lines extend right and labels re-anchor to the live edge every bar, so nothing scrolls off screen.
- Every marker shape, marker colour and line colour is an input.
- Every input uses `display = display.none`, so the chart status line shows only the indicator name.

## Matching the dashboard to TVMT

`Follow the alert's SL/TP` = **ON** in TVMT means the indicator's levels are the ones
traded, and TVMT's own SL 80 / TP 50 pips are only a fallback for alerts that omit them.
So the levels agree. What does **not** agree by default is the **exit model**.

With TVMT's **Take-Profit Ladder OFF**, `tp2` and `tp3` are never sent to the broker. The
whole position closes at the single `tp` value — every trade is binary, SL or TP1. A
dashboard that keeps walking a trade up to TP2 and TP3 is scoring exits that cannot happen.

Group **7 - Execution Model (mirror TVMT)** fixes that:

| Input | Set it to | Mirrors |
|---|---|---|
| Exit Model | `Single TP (TVMT ladder OFF)` | Take-Profit Ladder OFF — the default, and what is running today |
| | `TP ladder 33/33/34 (TVMT ladder ON)` | Take-Profit Ladder ON, with SL to breakeven at TP1 |
| Simulate Auto Breakeven | off | Auto Breakeven OFF |
| Breakeven Trigger (x SL distance) | 0.4 | Auto Breakeven trigger, as a fraction of the stop |
| Breakeven SL Offset (x SL distance) | 0.0 | SL offset from entry |

The breakeven trigger is expressed as a **fraction of the stop distance**, not in pips,
because TVMT's pip for gold is not necessarily this script's pip. `0.4` means "40% of the
way to a full stop loss, in profit".

### Expectancy is the number that matters

The dashboard now reports **Expectancy (R)** and **Total R**. Win rate on its own cannot
tell you whether a system works — 36% is excellent at 3R and fatal at 1.4R. Read the
expectancy row first; everything else is diagnosis.

`Total R` is the sum of every closed trade in R. Multiply it by your risk per trade to get
the currency result the account should have produced.

The header cell shows the active configuration at a glance: `1-TP IND` means single-TP
exits with the indicator supplying levels; `LADDER TVMT` means scale-out exits with TVMT
owning the levels.

## Who owns SL / TP — read this before trusting the dashboard

TVMT's **Trading Setup** page can apply its own SL/TP to every trade. When it does, the
levels this indicator draws are **not** the levels being traded, and the consequence is
easy to miss:

> The win-rate dashboard replays trades against the indicator's own SL/TP inputs. If TVMT
> is applying different distances, the dashboard is scoring **a different strategy from
> the one running on your account**. Win Rate, SL Hit and the TP1/TP2/TP3 percentages all
> describe a setup you are not trading.

The fix does not depend on which side wins the payload argument:

**Type the same distances into group `2 - Distance Method` that TVMT's Trading Setup
uses.** Once chart, dashboard and account agree, the dashboard becomes a real instrument
again and it stops mattering whether TVMT reads the payload or its own page.

`Who Sets SL / TP` in group **6 - Alerts** makes the choice explicit:

| Setting | Payload | Use when |
|---|---|---|
| `Indicator sends SL / TP to TVMT` (default) | full JSON with `entry`/`sl`/`tp`/`tp2`/`tp3` | TVMT honours the levels in the webhook |
| `TVMT Trading Setup (indicator levels are display only)` | `symbol`, `action`, `tv_time`, `tv_alert_id` only | TVMT applies its own Trading Setup levels |

TVMT mode reduces the payload to exactly the template the TVMT portal generates, so the
bridge can never be fed one set of numbers while the Trading Setup page applies another.
It applies to the **One alert (alert function)** method only — `alertcondition()` messages
must be compile-time constants, so the two-alert path always sends levels.

The dashboard now shows which mode is active next to the distance method (`Pip IND` or
`Pip TVMT`), and its bottom row shows the SL / TP1 distances in price. In TVMT mode that
row is labelled **MATCH TVMT** in red: those two numbers must equal your Trading Setup, or
every number above them is fiction.

## A note on the outer braces

The TVMT portal generates its own alert template **without** the outer `{ }`, noting that
this stops TradingView flagging the message as JSON. The script sends them, and that is
working today, so `Wrap Alert JSON In Outer Braces` defaults to **on**. Untick it only if
TVMT starts rejecting payloads.

It applies to the **One alert (alert function)** method only. TradingView requires
`alertcondition()` messages to be compile-time constants, so the two-alert path cannot be
switched at runtime and is always braced.

## Alert setup (TVMT webhook)
1. Right-click the chart → **Add alert**
2. Condition: **MFZ BYA IMACD2** → pick **MFZ BUY (TVMT)** or **MFZ SELL (TVMT)**
3. Trigger: **Once Per Bar Close**
4. Leave the pre-filled JSON message exactly as it is — do not add any text
5. Notifications tab → **Webhook URL** → paste your TVMT bridge URL

Alert payload (values arrive as raw numbers via `{{plot("title")}}`):

```json
{
  "symbol": "{{ticker}}",
  "action": "buy",
  "entry": {{plot("entry")}},
  "sl": {{plot("sl")}},
  "tp": {{plot("tp")}},
  "tp2": {{plot("tp2")}},
  "tp3": {{plot("tp3")}},
  "tv_time": "{{timenow}}",
  "tv_alert_id": "tv-{{ticker}}-buy-{{time}}"
}
```

`"tp"` carries TP1. Levels are matched by plot **title**, not by number, so plot order can never break the webhook.

## Why the markers are labels, not plotshapes
TradingView allows a maximum of **64 plot outputs per script**, and a `plotshape()` with a
variable colour compiles into three outputs (shape, colour, text colour). Offering nine
shape choices for each direction therefore cost 54 outputs on its own and tripped runtime
error **RE10140** (`too many plots (65)`) when the script was added to a chart.

Markers are drawn with `label.new()` instead. Labels are drawing objects, not plots, so the
full shape and colour choice is preserved at zero plot cost. The script now uses 11 of the
64 outputs. The trade-off is TradingView's 500-label cap, so markers show for roughly the
most recent 500 signals.

## Win-rate dashboard
Top-right table. It makes no signals of its own — it replays the indicator's own entries against the
same SL / TP levels bar by bar across loaded history. SL before TP1 = Loss, TP1 or better = Win.
It recalculates automatically when any input or the timeframe changes. It is a quick overview, not a
tick-precise backtester: when one bar touches both sides, the order is estimated from the bar open/high/low.
