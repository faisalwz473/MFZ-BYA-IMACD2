# MFZ BYA IMACD2

Pine Script **v6** overlay indicator for TradingView.
Signal engine adapted from *Impulse MACD [LazyBear]* (open source) and re-engineered
into a live-ready setup with Entry / SL / TP1 / TP2 / TP3 levels and a TVMT webhook alert.

## Files
- `MFZ_BYA_IMACD2.pine` — the complete indicator, ready to paste into the TradingView Pine Editor.

## Signal

**The crossing of the two lines is the only thing that fires an alert.**

- `md` (Impulse MACD line, driven by **MA Length**, slow) crosses **up** through
  `sb` (signal line, driven by **Signal Length**, fast) → **BUY**
- `md` crosses **down** through `sb` → **SELL**

No zone filter, no one-signal-per-direction filter, no trend filter. Each of
those could swallow a crossing and leave the alerts out of step with the chart,
so they were removed. Lot size, TP and SL are managed in TVMT.

`barstate.isconfirmed` is the only remaining gate. It sets *when* a crossing is
confirmed, never *whether* it counts — so signals print on bar close and never
repaint.

### Which cross is a BUY

One control, **Which Cross Is A BUY**:

| Setting | Meaning |
| --- | --- |
| `MACD crosses Signal Line (standard)` *(default)* | `md` up through `sb` = BUY. |
| `Signal Line crosses MACD (reversed)` | The **same** crossings, BUY and SELL swapped. |

Two lines can only swap places once per crossing, so both settings describe one
and the same event — this only decides which side gets called BUY. The standard
orientation is the one that follows price: `sb` is a moving average *of* `md`,
so `md` rising above it means momentum is turning up.

The old separate `Invert Buy / Sell` checkbox was removed. Having two controls
that do the same job made it easy to flip twice and land back where you started.

## Match the lengths to your pane indicator

**This was the cause of the misalignment.** The overlay was running MA Length 10
/ Signal Length 3 while the lower pane read `IMACD_LB 24 9` — a different, much
faster pair of lines. The two indicators were producing genuinely different
crossings, so the alerts could never line up with the pane no matter what else
was changed.

Read the pane legend and set the same two numbers here. `IMACD_LB 10 3` means MA
Length 10, Signal Length 3. The defaults are **10 / 3** to match that.

`sb` is a moving average **of** `md`, so a short Signal Length glues it to `md`
and the two cross on nearly every wiggle. Measured over 591 bars of gold-like
synthetic data:

| MA / Signal | Crossings | One signal per | |
| --- | --- | --- | --- |
| **10 / 3** | **101** | **~6 bars** | **default — matches `IMACD_LB 10 3`** |
| 12 / 6 | 55 | ~11 bars | |
| 21 / 7 | 27 | ~22 bars | |
| 24 / 9 | 23 | ~25 bars | |
| 34 / 9 | 16 | ~35 bars | LazyBear stock |

10/3 is the fastest of these and fires roughly **4.4× more often** than 24/9.
That is a deliberate choice, not a fault — but it does mean plenty of small
crossings alongside the big swings. To trade fewer, larger moves, raise both
numbers **and the pane with them** so the two stay in step.

> **TradingView stores input values in the saved chart layout, and a saved value
> outranks a new default.** After updating the script, open Settings → Inputs
> and confirm **MA Length** and **Signal Length** still read what your pane shows.

## Verified against the IMACD_LB source

Cross-checked line by line against the *Impulse MACD [LazyBear]* source. **The
two engines are mathematically identical at equal lengths:**

| Component | LazyBear | This script | |
| --- | --- | --- | --- |
| Smoothed MA | `(smma[1]*(len-1)+src)/len`, seeded `sma()` | `ta.rma()` | identical¹ |
| Zero-lag EMA | `ema1 + (ema1 - ema2)` | same | identical |
| `md` | `(mi>hi) ? mi-hi : (mi<lo) ? mi-lo : 0` | same | identical |
| `sb` | `sma(md, lengthSignal)` | `ta.sma(...)` | identical |
| Source | `hlc3` (hard-coded) | `hlc3` (input) | identical by default |

¹ LazyBear's recursion is Wilder smoothing with `alpha = 1/len`, which is what
`ta.rma()` computes. Checked numerically over 800 bars at lengths 3/9/10/24/34 —
worst difference **4.5e-12**, float noise only. The rewrite to `ta.rma()` was
needed because a self-referencing `smma[1]` inside a function throws a runtime
error in Pine v5/v6; it changes nothing numerically.

> **Keep Price Source on `hlc3`.** LazyBear hard-codes it; it is an input here,
> so changing it silently de-synchronises this script from the pane.

### The easiest way to verify a signal

LazyBear plots `sh = md - sb` as the blue **ImpulseHisto** histogram, and this
script detects a cross on the sign of *exactly that same quantity*. So:

> **A signal fires precisely when the blue histogram crosses zero.**

That is far easier to read than watching two curves converge. A marker where the
blue histogram did **not** cross zero means something is genuinely wrong — report
it. A marker where it did means the script is working.

### Do not read the md line's colour as a signal

LazyBear colours that line with:

```
mdc = src>mi ? (src>hi ? lime : green) : (src<lo ? red : orange)
```

| Condition | Colour |
| --- | --- |
| `src > mi` and `src > hi` | lime |
| `src > mi` and `src <= hi` | green |
| `src <= mi` and `src < lo` | red |
| `src <= mi` and `src >= lo` | orange |

Every branch compares **price** against the bands. Not one compares `md` against
`sb`. The colour says nothing about the crossing — green does **not** mean a BUY
is due. It is a separate reading that can and does disagree with the crossing,
and mistaking one for the other is an easy way to conclude the alerts are wrong
when they aren't.

## Dashboard diagnostics

Five rows at the bottom of the table exist to verify the alerts track the lines:

| Row | Meaning |
| --- | --- |
| `Crossings` | Crossings found between `md` and `sb`. |
| `Alerts Fired` | Signals actually sent. **Must equal `Crossings`** — it turns red if not. |
| `One Signal Per` | Live crossing rate, for tuning Signal Length. |
| `md vs sb` | Which line is on top right now. |
| `Last Cross` | Direction and age of the most recent crossing. |

`Crossings` and `Alerts Fired` diverging would mean something is standing between
a crossing and its alert. With the filters removed, nothing can.

## Checking alignment against the pane indicator

This script is an **overlay**, so `md` and `sb` are not drawn on it — Pine cannot
plot into a lower pane from an overlay script. To compare against
*Impulse MACD [LazyBear]* in the lower pane, that pane copy must use the same
numbers or the lines you are watching are not the ones firing your alerts:

- MA Length **10** (LazyBear ships 34)
- Signal Length **3** (LazyBear ships 9)
- Source **hlc3**

The `md vs sb` and `Last Cross` dashboard rows let you check the two agree
without eyeballing it.

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
2. Condition: **BYA IMACD2** → pick **MFZ BUY (TVMT)** or **MFZ SELL (TVMT)**
3. Trigger: **Once Per Bar Close**
4. Leave the pre-filled JSON message exactly as it is — do not add any text
5. Notifications tab → tick **Webhook URL** → enter your TVMT bridge URL

Create **both** alerts — BUY and SELL are separate conditions.

### If the Webhook URL field refuses your paste

A known TradingView quirk, confirmed by TVMT support: a long-running browser
session stops accepting input in the Webhook URL field. The field looks normal,
the checkbox is ticked, but nothing lands and Create reports
*"A Webhook URL is required."*

**Log out of TradingView and log back in.** A page refresh is not enough.

Ruled out along the way, so don't waste time on them: it is not the plan (the
field validates rather than being greyed out), not the checkbox, not the alert
count, and nothing to do with this indicator. Two useful checks while
diagnosing — type `https://example.com/test` by hand to prove the field accepts
input at all, and remember that example.com answers POST with **405 Method Not
Allowed**, so that placeholder will always show a delivery failure in the log.

### Verify the direction before trading

Each `alertcondition` hardcodes its own direction, so the alert list preview is
proof of which condition you picked:

```
BYA IMACD2 5m BUY    { "symbol": "{{ticker}}", "action": "buy",  "tv_time": ...
BYA IMACD2 5m SELL   { "symbol": "{{ticker}}", "action": "sell", "tv_time": ...
```

If the SELL row reads `"action": "buy"`, the wrong condition was selected in the
second dropdown — delete the alert and recreate it. An `"entry":` field in either
row means the alert was created against an older version of the script and is
stale.

### Signal-only payload

**TVMT owns entry price, TP, SL and lot size.** The alert therefore carries only
*what* happened and *when*:

```json
{
  "symbol": "{{ticker}}",
  "action": "buy",
  "tv_time": "{{timenow}}",
  "tv_alert_id": "tv-{{ticker}}-buy-{{time}}"
}
```

No `entry`, `sl`, `tp`, `tp2` or `tp3`. Sending levels the bridge is going to
overrule is at best noise, and at worst a payload it rejects. This matches the
field order of the known-working MSB alerts (`symbol`, `action`, `tv_time`).

The five hidden `entry`/`sl`/`tp` plots that fed `{{plot("...")}}` placeholders
were removed along with those fields — nothing reads them any more.

> **The chart levels are now indicative only.** The script still draws Entry /
> SL / TP1–3 and the dashboard still scores them, because they are useful for
> reading and tuning the signal. But TVMT sets the levels that actually get
> traded, so **the dashboard win rate measures a hypothetical 1:1 exit plan, not
> your live results.** Judge the signal by it; do not judge your account by it.

### If TVMT rejects the payload

Open a working MSB alert, copy its full Message body, and compare. If TVMT needs
a field this payload lacks (a licence id, a risk value, a symbol suffix), the
two `alertcondition` message strings near the bottom of the script are the only
place to change.

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
