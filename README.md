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

# MT5 Expert Advisor — Stochastic 21 / 3 / 5 cross (H1)

`mt5/MFZ_Stochastic_Cross_EA.mq5` trades the %K / %D crossover of Stochastic (21, 3, 5) on **H1** (v1.50 defaults), with an H4 Stochastic trend filter and an ATR stop.

| Event (on a closed M5 bar) | Action |
|---|---|
| %K crosses **up** through %D | close any SELL (its take profit) → open **BUY** |
| %K crosses **down** through %D | close any BUY (its take profit) → open **SELL** |

- **Entry mode** input:
  - `Bar close` (default): acts on a cross confirmed by a **closed** M5 candle; entry at the next candle's open. No false crosses, ~1 candle later.
  - `Instant`: acts the moment %K crosses %D **inside** the forming candle. Faster, but a cross that reverses inside the
    candle exits the trade straight away. Max **one entry per candle** to limit whipsaw; exits are never blocked.
- **Zone filter** (off by default, entries only): BUY only if the cross happens at or below `Buy zone` (default 30),
  SELL only if at or above `Sell zone` (default 70). The level used is %D at the cross. Exits still happen on every cross.
- The signal timeframe is an input (default `M5`), so the EA can sit on any chart.
- One position per direction, tracked by **Magic number** — other EAs and manual trades are not touched.
- If a close fails, the opposite entry is skipped so you never end up hedged by accident.
- Inputs: Stochastic K/D/Slowing, MA method, price field, lot size, trade direction (both / buy only / sell only),
  optional safety SL / TP in points (0 = off), `Reverse` (set false to only exit on a cross and wait for the next one to enter),
  max spread filter, slippage, magic, comment.

## One copy per symbol (v1.51)
Two copies of the EA on the same symbol with the same Magic number manage each other's trades: one closes the
other's positions on its own crosses and blocks its entries. v1.51 refuses to start when another copy with the
same symbol + Magic is already running (it stores `MFZStoch_<symbol>_<magic>_<chart id>` in the terminal's
global variables, F3). The chart's top-left corner shows the running version and its main settings.

## Validated defaults (v1.50)
XAUUSD, Strategy Tester "Every tick based on real ticks", 0.01 lot, 3,000 deposit, identical settings in every period:

| Period | Net | Profit factor | Trades | Win % | Max equity DD |
|---|---|---|---|---|---|
| Jan–Mar 2026 (history quality 0%) | +942.62 | 1.52 | 136 | 38.2 | 11.6% |
| Apr–Jun 2026 (history quality 92%) | +523.84 | 1.46 | 111 | 38.7 | 12.7% |
| Jul–Sep 2026 (history quality 100%) | +315.73 | 1.35 | 110 | 46.4 | 6.3% |

The same Stochastic cross on M5 lost about the spread on every trade (PF 0.85) and on M15 still lost (PF 0.94):
on gold this edge only appears once moves between crosses are large compared with the spread.
Expect losing streaks of 6–8 trades and drawdowns of 10–15%.

## Stop loss, break-even and trend filter (v1.40)
- **Stop loss mode** `ATR multiple` (default): SL = ATR(14) of the signal timeframe × 2.0. It widens on volatile
  symbols and quiet hours tighten it, so the same settings work on XAUUSD, FixedVol100, forex, etc.
  `Fixed price distance` keeps the v1.30 behaviour (`15.0` = a 15.00 price move).
- **Break-even** (off by default): once a trade is ATR × N in profit, the stop moves to entry + spread.
- **Trend filter** (on by default): only BUY when the M15 Stochastic(21,3,5) %K is above %D, only SELL when it is below.
  Exits on the M5 cross are not affected.

## Invert signals (v1.30)
`Invert signals = true` trades the opposite way: %K crossing **up** opens a SELL, crossing **down** opens a BUY.
Exits still happen on every cross. The zone filter still judges the cross itself (UP crosses low, DOWN crosses high).
Off by default — test it in the Strategy Tester against the normal direction before using it.

## Protection filters (v1.20)
All optional; exits on a Stochastic cross are never blocked by a filter.

| Filter | Inputs | Tester |
|---|---|---|
| Safety stop loss | **price distance**, default `15.0` (XAUUSD: a $15 move ≈ $15 per 0.01 lot on both 2- and 3-decimal feeds; EURUSD would be e.g. `0.0015`). Never tighter than the broker's minimum stop level | yes |
| Daily loss limit / profit target | money in account currency; when hit → close all, no new trades until the next server day | yes |
| Trading hours | start / end hour in **broker server time**, optional close outside hours | yes |
| Friday close | close all and stop from this hour on Friday (weekend gap protection) | yes |
| News filter | currencies (default `USD`), high impact (+ medium optional), minutes before / after, optional close before news | **no** — MT5 has no calendar data in the Strategy Tester |

The news filter reads MT5's built-in economic calendar (`Calendar` tab in the Toolbox).

## Install
1. MT5 → **File → Open Data Folder** → `MQL5/Experts/` → copy `MFZ_Stochastic_Cross_EA.mq5` there.
2. Open it in **MetaEditor** and press **Compile** (F7).
3. In MT5 Navigator → Expert Advisors, drag the EA onto a chart, enable **Algo Trading**.
4. Test first in the **Strategy Tester** (Ctrl+R), model "Every tick based on real ticks", timeframe M5.

## Comparing the modes in the Strategy Tester
Use **Every tick based on real ticks** — Instant mode is meaningless on "1 minute OHLC" or "Open prices only".

Quickest way: one optimization run covering all 4 combinations.
1. Strategy Tester → Settings: Expert = this EA, XAUUSD, M5, last 3 months, **Optimization = Slow complete algorithm**.
2. Inputs tab: tick the box next to **Entry mode** (Start = Bar close, Stop = Instant) and **Use zone filter** (false → true).
   Leave every other input unticked.
3. Start. The **Optimization Results** tab lists one row per combination with profit, drawdown, trades and profit factor.
4. Double-click a row to run that combination as a single test and see its trades.
