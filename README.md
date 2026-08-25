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
