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

---

# MSB V1

Pine Script **v6** overlay indicator for TradingView. A modified derivative of
*Market Structure Break & Order Block* (MSB-OB) by EmreKb, MPL-2.0, re-engineered
with Entry / SL / TP1 / TP2 / TP3 levels, a TVMT webhook alert, and a win-rate
engine that scores execution costs and stop-to-breakeven.

## Files
- `MSB_V1.pine` — the complete indicator, ready to paste into the TradingView Pine Editor.

## Signal
A swing high is the highest high of the last `ZigZag Length` bars; a swing low is
the lowest low. When price closes beyond the last swing level and pushes past it
by `Fib Factor` of the leg, structure is broken:

- close **above** the last swing high, plus the margin → **BUY**
- close **below** the last swing low, plus the margin → **SELL**

A break is only valid against the current market state, so signals strictly
alternate BUY, SELL, BUY… and exactly one setup is live at a time.

`Break Trigger` also offers `Pivot Comparison (original)`, the EmreKb behaviour.
Avoid it for live trading: a pivot is only recorded once price has already
reversed away from it, so the signal lands roughly a ZigZag Length **after** the
turn — a BUY at the top and a SELL at the bottom.

## Alerts: the two routes are mutually exclusive

| Route | `Alert Method` | Alerts to create |
|---|---|---|
| Script writes the JSON | `One alert (alert function)` | **one**, Condition → `MSB V1` → *Any alert() function call* |
| Message box holds the JSON | `Two alerts` | **two**, `MSB BUY (TVMT)` and `MSB SELL (TVMT)`, trigger *Once Per Bar Close* |

The `alert()` calls are gated on this input, so an *Any alert() function call*
alert created while the setting reads `Two alerts` fires **nothing, silently**.
The single-alert route is preferred: one alert covers both directions, the
`action` always matches the marker, and it is the only route that can honour
`Webhook Symbol Override`.

**TradingView freezes both the script and its input settings into an alert when
the alert is created.** Editing either afterwards does not update a running
alert. After any change, delete the alert and create a new one — otherwise the
bridge keeps trading the old configuration while the chart shows the new one.

Never point the four zone alerts (`Price In … Zone`) at a trading webhook. They
send plain text, and the conditions are levels rather than edges, so with *Once
Per Bar Close* they fire on every bar while price sits inside a zone.

## Gold pip warning
`Pip Size Mode = Auto` computes `10 × mintick`, which only lands on the
conventional gold pip of `0.10` for a **two**-decimal feed. On a **three**-decimal
gold feed Auto returns `0.01` — one tenth of the intended value. That silently
shrinks `Structure SL Buffer`, and a broker EA sizing by `risk ÷ stop` will
inflate position size to compensate.

On a 3-decimal gold chart: `Pip Size Mode = Manual`, `Manual Pip Size = 0.10`.

Quick check with `Show Distance In Pips On Labels` on — a stop sitting about 4.40
from entry should read **~44 pips**, not ~440.

## Win rate dashboard
Makes no signals of its own. It replays the indicator's own entries against the
same SL / TP levels, bar by bar across loaded history. A quick overview, not a
tick-precise backtester: when one bar touches both sides, the order is estimated
from the bar open.

**Judge configurations on `Expectancy / trade`, never on `Win Rate`.** Win rate
is computed on resolved trades only and excludes the cut-by-reversal bucket,
which is systematically negative — a strategy can show 58% wins and still make
about zero.

### Execution costs (group 10a)
`Round-Turn Cost (pips)` is charged against every trade the engine scores — wins,
losses, breakevens and cut trades alike. Expired setups never opened, so they pay
nothing. Default `0` reproduces the original gross figures exactly.

Measure it rather than guess: compare one real broker fill against the `entry`
value in that alert's payload, then add the spread paid. On gold with Manual pip
`0.10`, a `0.35` difference is `3.5` pips.

### Stop-to-breakeven (group 10a)
Because signals alternate, an open trade is cut whenever the next signal arrives,
and that bucket is systematically negative. Raising `ZigZag Length` does **not**
fix it — longer swings push signals further apart but push TP and SL out by the
same proportion, so the cut ratio barely moves. Churn is a property of the
alternating-signal design.

`Model Stop-To-Breakeven` moves the modelled stop to entry (plus an optional
offset) once the trade is far enough ahead, so a trade later reversed exits near
0R instead of −1R. Trigger in `R multiple` or in `Pips` — use Pips to mirror a
broker EA that expresses it that way, or the dashboard measures a different
strategy from the one being traded.

Expect `Wins` to fall as `Breakeven` rises. That is the mechanism working, not a
worse strategy. Compare Expectancy.

### Reading the table
`Resolved (SL/BE/TP1)` = `Wins` + `Losses` + `Breakeven`. The header cell tags
every screenshot with the scoring model that produced it — distance method, `+ BE`
when breakeven is modelled, and `GROSS` or `NET` depending on whether a cost is
being charged.

Risk is fixed at entry from the **original** stop, and every R figure divides by
it. That is required: once the breakeven model moves the working stop toward
entry, the live entry-to-stop distance shrinks toward zero and would blow up any
ratio computed from it.
