//+------------------------------------------------------------------+
//|                                     MFZ_Stochastic_Cross_EA.mq5 |
//|  Stochastic (10, 3, 3) %K / %D crossover Expert Advisor for MT5  |
//|                                                                  |
//|  Rules (signal timeframe, default M5):                           |
//|   - %K crosses UP   %D -> close SELL (take profit) + open BUY    |
//|   - %K crosses DOWN %D -> close BUY  (take profit) + open SELL   |
//|                                                                  |
//|  Entry mode:                                                     |
//|   - Bar close : act on a cross confirmed by a CLOSED candle       |
//|   - Instant   : act the moment %K crosses %D inside the candle    |
//|  Zone filter (optional, entries only):                           |
//|   - BUY  only if the cross happens at or below the Buy zone      |
//|   - SELL only if the cross happens at or above the Sell zone     |
//|   Exits always happen on every opposite cross.                   |
//|  Invert signals (optional): cross UP sells, cross DOWN buys.      |
//|  Trend filter (optional): only trade in the direction of the      |
//|  higher-timeframe Stochastic (%K above %D = BUY only).            |
//|  Stop loss: fixed price distance or ATR multiple; optional        |
//|  break-even once a trade is X ATR in profit.                      |
//|                                                                  |
//|  Protection filters (all optional):                              |
//|   - Daily loss limit / daily profit target -> close all and stop  |
//|     trading for the rest of the day                               |
//|   - Trading hours (server time), optional close outside hours     |
//|   - Friday close (weekend gap protection)                         |
//|   - News filter: no new entries around high-impact news, optional |
//|     close before news (live/demo only - the Strategy Tester has   |
//|     no calendar data)                                             |
//+------------------------------------------------------------------+
#property copyright "MFZ"
#property version   "1.41"

#include <Trade\Trade.mqh>

enum ENUM_TRADE_DIRECTION
  {
   DIR_BOTH      = 0, // Buy and Sell
   DIR_BUY_ONLY  = 1, // Buy only
   DIR_SELL_ONLY = 2  // Sell only
  };

enum ENUM_SL_MODE
  {
   SL_ATR   = 0, // ATR multiple (adapts to volatility)
   SL_FIXED = 1  // Fixed price distance
  };

enum ENUM_ENTRY_MODE
  {
   ENTRY_BAR_CLOSE = 0, // Bar close (confirmed cross)
   ENTRY_INSTANT   = 1  // Instant (cross inside the candle)
  };

//--- Signal
input group "Stochastic signal"
input ENUM_TIMEFRAMES InpTimeframe   = PERIOD_M5;    // Signal timeframe
input int             InpKPeriod     = 10;           // %K period
input int             InpDPeriod     = 3;            // %D period
input int             InpSlowing     = 3;            // Slowing
input ENUM_MA_METHOD  InpMaMethod    = MODE_SMA;     // MA method
input ENUM_STO_PRICE  InpPriceField  = STO_LOWHIGH;  // Price field
input ENUM_ENTRY_MODE InpEntryMode   = ENTRY_BAR_CLOSE; // Entry mode

//--- Zone filter
input group "Zone filter (entries only, exits always on cross)"
input bool            InpUseZone     = false;        // Use zone filter
input double          InpBuyZone     = 30.0;         // BUY only if cross is at or below this level
input double          InpSellZone    = 70.0;         // SELL only if cross is at or above this level

//--- Trading
input group "Trading"
input ENUM_TRADE_DIRECTION InpDirection = DIR_BOTH;  // Trade direction
input double          InpLots        = 0.01;         // Lot size
input ENUM_SL_MODE    InpSlMode      = SL_ATR;       // Stop loss mode
input double          InpStopLossDist = 15.0;        // Fixed mode: stop loss as PRICE distance (0 = off; XAUUSD 15.0 = $15 move)
input double          InpTakeProfitDist = 0.0;       // Fixed mode: take profit as PRICE distance (0 = off, exit on cross)
input int             InpAtrPeriod   = 14;           // ATR mode: ATR period (signal timeframe)
input double          InpAtrSlMult   = 2.0;          // ATR mode: stop loss = ATR x this (0 = off)
input double          InpAtrTpMult   = 0.0;          // ATR mode: take profit = ATR x this (0 = off, exit on cross)
input double          InpBreakEvenAtr = 0.0;         // Move SL to entry once profit reaches ATR x this (0 = off)
input bool            InpInvert      = false;        // Invert signals (cross UP = SELL, cross DOWN = BUY)
input bool            InpReverse     = true;         // Open the opposite trade on the same cross that exits
input int             InpMaxSpreadPts = 0;           // Max spread in points for new entries (0 = off)
input int             InpSlippagePts = 20;           // Max slippage in points
input ulong           InpMagic       = 21305;        // Magic number
input string          InpComment     = "MFZ Stoch"; // Order comment

//--- Higher-timeframe trend filter
input group "Trend filter (higher-timeframe Stochastic)"
input bool            InpUseHtf      = true;         // Use trend filter
input ENUM_TIMEFRAMES InpHtfTimeframe = PERIOD_M15;  // Trend timeframe
input int             InpHtfK        = 21;           // Trend %K period
input int             InpHtfD        = 3;            // Trend %D period
input int             InpHtfSlowing  = 5;            // Trend slowing

//--- Daily protection
input group "Daily protection (account currency, 0 = off)"
input double          InpDailyLossLimit  = 0.0;     // Daily loss limit: close all + stop for the day
input double          InpDailyProfitTarget = 0.0;   // Daily profit target: close all + stop for the day

//--- Trading hours
input group "Trading hours (broker server time)"
input bool            InpUseHours    = false;        // Use trading hours
input int             InpStartHour   = 10;           // Start hour (0-23)
input int             InpEndHour     = 22;           // End hour (0-23, no new entries from this hour)
input bool            InpCloseOutsideHours = false;  // Close open trades outside trading hours
input int             InpFridayCloseHour = 0;        // Friday: close all + stop from this hour (0 = off)

//--- News filter
input group "News filter (live/demo only, not in Strategy Tester)"
input bool            InpUseNews     = false;        // Use news filter
input string          InpNewsCurrencies = "USD";     // Currencies to watch (comma separated)
input bool            InpNewsMedium  = false;        // Also block medium-impact news
input int             InpNewsBeforeMin = 30;         // Block entries this many minutes before news
input int             InpNewsAfterMin  = 30;         // Block entries this many minutes after news
input bool            InpNewsCloseBefore = true;     // Close open trades when the before-news window starts

//--- Globals
CTrade   trade;
int      g_stoch = INVALID_HANDLE;
int      g_htf   = INVALID_HANDLE;
int      g_atr   = INVALID_HANDLE;
datetime g_lastBarTime  = 0;   // Bar close mode: last bar processed
int      g_lastSign     = 0;   // Instant mode: last seen side of %K vs %D (+1 above, -1 below)
datetime g_lastEntryBar = 0;   // Instant mode: candle of the last entry (max one entry per candle)
datetime g_lockedDay    = 0;   // day on which the daily limit was hit (no more trading that day)
datetime g_lastRiskCheck = 0;  // throttle for the daily P/L check (once per second)
string   g_newsCurrencies[];   // parsed InpNewsCurrencies
bool     g_newsEnabled  = false;
datetime g_newsCheckTime = 0;  // news window is refreshed once per minute
bool     g_newsBlock    = false; // inside a news window
bool     g_newsUpcoming = false; // the window is before an event (not after)
string   g_newsTitle    = "";

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpKPeriod < 1 || InpDPeriod < 1 || InpSlowing < 1)
     {
      Print("Invalid Stochastic periods");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpLots <= 0.0)
     {
      Print("Lot size must be greater than zero");
      return(INIT_PARAMETERS_INCORRECT);
     }
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(InpLots < minLot - 1e-9)
     {
      PrintFormat("Lot size %.2f is below the minimum lot %.2f for %s - set Lot size to at least %.2f",
                  InpLots, minLot, _Symbol, minLot);
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpUseZone && (InpBuyZone < 0.0 || InpBuyZone > 100.0 || InpSellZone < 0.0 || InpSellZone > 100.0))
     {
      Print("Zone levels must be between 0 and 100");
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(InpUseHours && (InpStartHour < 0 || InpStartHour > 23 || InpEndHour < 0 || InpEndHour > 23))
     {
      Print("Trading hours must be between 0 and 23");
      return(INIT_PARAMETERS_INCORRECT);
     }

   //--- news filter setup
   g_newsEnabled = false;
   ArrayResize(g_newsCurrencies, 0);
   if(InpUseNews)
     {
      if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION))
         Print("News filter is not available in the Strategy Tester - it is ignored in this test");
      else
        {
         string parts[];
         int n = StringSplit(InpNewsCurrencies, ',', parts);
         for(int i = 0; i < n; i++)
           {
            string c = parts[i];
            StringTrimLeft(c);
            StringTrimRight(c);
            StringToUpper(c);
            if(StringLen(c) == 0)
               continue;
            int sz = ArraySize(g_newsCurrencies);
            ArrayResize(g_newsCurrencies, sz + 1);
            g_newsCurrencies[sz] = c;
           }
         g_newsEnabled = (ArraySize(g_newsCurrencies) > 0);
        }
     }
   g_newsCheckTime = 0;
   g_newsBlock     = false;
   g_newsUpcoming  = false;

   if(InpUseHtf)
     {
      g_htf = iStochastic(_Symbol, InpHtfTimeframe, InpHtfK, InpHtfD, InpHtfSlowing,
                          InpMaMethod, InpPriceField);
      if(g_htf == INVALID_HANDLE)
        {
         PrintFormat("Failed to create trend Stochastic handle, error %d", GetLastError());
         return(INIT_FAILED);
        }
     }
   if(InpSlMode == SL_ATR || InpBreakEvenAtr > 0.0)
     {
      g_atr = iATR(_Symbol, InpTimeframe, MathMax(InpAtrPeriod, 1));
      if(g_atr == INVALID_HANDLE)
        {
         PrintFormat("Failed to create ATR handle, error %d", GetLastError());
         return(INIT_FAILED);
        }
     }

   g_stoch = iStochastic(_Symbol, InpTimeframe, InpKPeriod, InpDPeriod, InpSlowing,
                         InpMaMethod, InpPriceField);
   if(g_stoch == INVALID_HANDLE)
     {
      PrintFormat("Failed to create Stochastic handle, error %d", GetLastError());
      return(INIT_FAILED);
     }

   if(InpSlMode == SL_ATR)
      PrintFormat("%s: SL = ATR(%d) x %.2f, TP = ATR x %.2f, break-even at ATR x %.2f. Signals %s, trend filter %s.",
                  _Symbol, InpAtrPeriod, InpAtrSlMult, InpAtrTpMult, InpBreakEvenAtr,
                  InpInvert ? "INVERTED" : "normal",
                  InpUseHtf ? EnumToString(InpHtfTimeframe) : "off");
   else
      PrintFormat("%s: %d digits, point %s. Fixed SL = %s price (%.0f points), TP = %s price. Signals %s, trend filter %s.",
                  _Symbol, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS),
                  DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_POINT), 5),
                  DoubleToString(InpStopLossDist, 5),
                  InpStopLossDist / SymbolInfoDouble(_Symbol, SYMBOL_POINT),
                  DoubleToString(InpTakeProfitDist, 5),
                  InpInvert ? "INVERTED" : "normal",
                  InpUseHtf ? EnumToString(InpHtfTimeframe) : "off");

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePts);
   trade.SetTypeFillingBySymbol(_Symbol);

   // Do not trade a cross that already happened before the EA was attached.
   g_lastBarTime  = iTime(_Symbol, InpTimeframe, 0);
   g_lastSign     = 0;
   g_lastEntryBar = 0;
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_stoch != INVALID_HANDLE)
      IndicatorRelease(g_stoch);
   if(g_htf != INVALID_HANDLE)
      IndicatorRelease(g_htf);
   if(g_atr != INVALID_HANDLE)
      IndicatorRelease(g_atr);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   ManageProtection();
   ManageBreakEven();

   datetime barTime = iTime(_Symbol, InpTimeframe, 0);
   if(barTime == 0)
      return;

   int    signal = 0;
   double level  = 0.0;

   if(InpEntryMode == ENTRY_INSTANT)
     {
      if(!GetInstantSignal(signal, level))
         return;
     }
   else
     {
      if(barTime == g_lastBarTime)
         return;                          // act once per new candle
      if(!GetClosedBarSignal(signal, level))
         return;                          // data not ready - retry on the next tick
      g_lastBarTime = barTime;
     }

   if(signal != 0)
      HandleSignal(signal, level, barTime);
  }

//+------------------------------------------------------------------+
//| Bar close mode: +1 / -1 when %K crossed %D on the last CLOSED    |
//| candle. level = %D at that candle (where the cross happened).     |
//+------------------------------------------------------------------+
bool GetClosedBarSignal(int &signal, double &level)
  {
   signal = 0;
   const int depth = 12;
   double k[], d[];
   ArraySetAsSeries(k, true);
   ArraySetAsSeries(d, true);

   if(CopyBuffer(g_stoch, MAIN_LINE,   0, depth, k) != depth) return(false);
   if(CopyBuffer(g_stoch, SIGNAL_LINE, 0, depth, d) != depth) return(false);

   level = d[1];
   double curr = k[1] - d[1];             // last closed candle
   if(curr == 0.0)
      return(true);                       // touching, not crossed yet

   // previous non-zero difference (handles candles where %K == %D exactly)
   double prev = 0.0;
   for(int i = 2; i < depth && prev == 0.0; i++)
      prev = k[i] - d[i];
   if(prev == 0.0)
      return(true);

   if(prev < 0.0 && curr > 0.0)
      signal = 1;
   else if(prev > 0.0 && curr < 0.0)
      signal = -1;
   return(true);
  }

//+------------------------------------------------------------------+
//| Instant mode: +1 / -1 the moment %K moves to the other side of   |
//| %D on the forming candle. Every side change is reported, so a    |
//| cross that reverses inside the candle exits the trade at once.    |
//+------------------------------------------------------------------+
bool GetInstantSignal(int &signal, double &level)
  {
   signal = 0;
   double k[], d[];
   if(CopyBuffer(g_stoch, MAIN_LINE,   0, 1, k) != 1) return(false);
   if(CopyBuffer(g_stoch, SIGNAL_LINE, 0, 1, d) != 1) return(false);

   level = d[0];
   double diff = k[0] - d[0];
   if(diff == 0.0)
      return(true);
   int sign = (diff > 0.0) ? 1 : -1;

   if(g_lastSign == 0)
     {
      g_lastSign = sign;                  // first reading after start: no trade
      return(true);
     }
   if(sign != g_lastSign)
     {
      g_lastSign = sign;
      signal     = sign;
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Exit on every cross, then enter if all filters allow it.         |
//+------------------------------------------------------------------+
void HandleSignal(const int cross, const double level, const datetime barTime)
  {
   // cross: +1 = %K crossed UP, -1 = crossed DOWN. signal: trade direction.
   const int signal = InpInvert ? -cross : cross;
   bool closedAny = false;
   ENUM_POSITION_TYPE exitType = (signal > 0) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
   string dirText = (signal > 0) ? "BUY" : "SELL";

   // Take profit / exit for the opposite trade. Never open a new trade
   // while the old one failed to close.
   if(!ClosePositions(exitType, closedAny))
      return;

   if(signal > 0 && InpDirection == DIR_SELL_ONLY) return;
   if(signal < 0 && InpDirection == DIR_BUY_ONLY)  return;
   if(!InpReverse && closedAny)                    return;

   string blocked = EntryBlockReason();
   if(blocked != "")
     {
      PrintFormat("%s skipped: %s", dirText, blocked);
      return;
     }

   // Zone filter judges the cross itself (UP crosses low, DOWN crosses high).
   if(InpUseZone)
     {
      if(cross > 0 && level > InpBuyZone)
        {
         PrintFormat("%s skipped by zone filter: UP cross at %.1f is above %.1f", dirText, level, InpBuyZone);
         return;
        }
      if(cross < 0 && level < InpSellZone)
        {
         PrintFormat("%s skipped by zone filter: DOWN cross at %.1f is below %.1f", dirText, level, InpSellZone);
         return;
        }
     }

   if(InpUseHtf)
     {
      int trend = HtfTrend();
      if(trend == 0)
        {
         PrintFormat("%s skipped: trend filter data not ready", dirText);
         return;
        }
      if(trend != signal)
        {
         PrintFormat("%s skipped by trend filter: %s Stochastic points %s", dirText,
                     EnumToString(InpHtfTimeframe), trend > 0 ? "UP" : "DOWN");
         return;
        }
     }

   if(InpEntryMode == ENTRY_INSTANT && g_lastEntryBar == barTime)
     {
      PrintFormat("%s skipped: already entered once in this candle", dirText);
      return;
     }

   if(OpenPosition(signal > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL))
     {
      g_lastEntryBar = barTime;
      PrintFormat("%s opened (%s mode%s), %s cross at %.1f", dirText,
                  InpEntryMode == ENTRY_INSTANT ? "Instant" : "Bar close",
                  InpInvert ? ", inverted" : "", cross > 0 ? "UP" : "DOWN", level);
     }
  }

//+------------------------------------------------------------------+
//| Protection that runs on every tick: daily limits, hours, Friday, |
//| news. Closes trades when a rule says so.                          |
//+------------------------------------------------------------------+
void ManageProtection()
  {
   datetime now = TimeCurrent();
   if(now == 0)
      return;

   //--- daily loss limit / profit target (checked once per second)
   if((InpDailyLossLimit > 0.0 || InpDailyProfitTarget > 0.0) && now != g_lastRiskCheck)
     {
      g_lastRiskCheck = now;
      datetime today = DayStart(now);
      if(g_lockedDay != today)
        {
         double pnl = TodayPnL(today, now);
         string why = "";
         if(InpDailyLossLimit > 0.0 && pnl <= -InpDailyLossLimit)
            why = StringFormat("daily loss limit hit (%.2f)", pnl);
         else if(InpDailyProfitTarget > 0.0 && pnl >= InpDailyProfitTarget)
            why = StringFormat("daily profit target reached (%.2f)", pnl);
         if(why != "")
           {
            g_lockedDay = today;
            PrintFormat("%s - closing all trades, no new trades until tomorrow", why);
            CloseAll();
           }
        }
     }

   //--- trading hours / Friday close
   if(InpUseHours && InpCloseOutsideHours && !InSession(now))
      CloseAll();
   if(IsFridayClose(now))
      CloseAll();

   //--- news
   if(g_newsEnabled)
     {
      UpdateNewsWindow();
      if(g_newsBlock && g_newsUpcoming && InpNewsCloseBefore)
         CloseAll();
     }
  }

//+------------------------------------------------------------------+
//| "" if a new entry is allowed, otherwise the reason it is not.    |
//+------------------------------------------------------------------+
string EntryBlockReason()
  {
   datetime now = TimeCurrent();
   if(g_lockedDay != 0 && g_lockedDay == DayStart(now))
      return("daily limit reached - trading stopped for today");
   if(InpUseHours && !InSession(now))
      return("outside trading hours");
   if(IsFridayClose(now))
      return("Friday close time");
   if(g_newsEnabled)
     {
      UpdateNewsWindow();
      if(g_newsBlock)
         return("news filter (" + g_newsTitle + ")");
     }
   return("");
  }

//+------------------------------------------------------------------+
datetime DayStart(const datetime t)
  {
   MqlDateTime d;
   TimeToStruct(t, d);
   d.hour = 0;
   d.min  = 0;
   d.sec  = 0;
   return(StructToTime(d));
  }

//+------------------------------------------------------------------+
bool InSession(const datetime t)
  {
   if(!InpUseHours || InpStartHour == InpEndHour)
      return(true);
   MqlDateTime d;
   TimeToStruct(t, d);
   if(InpStartHour < InpEndHour)
      return(d.hour >= InpStartHour && d.hour < InpEndHour);
   return(d.hour >= InpStartHour || d.hour < InpEndHour);   // overnight session
  }

//+------------------------------------------------------------------+
bool IsFridayClose(const datetime t)
  {
   if(InpFridayCloseHour <= 0)
      return(false);
   MqlDateTime d;
   TimeToStruct(t, d);
   return(d.day_of_week == 5 && d.hour >= InpFridayCloseHour);
  }

//+------------------------------------------------------------------+
//| Today's closed P/L for this EA plus the floating P/L of its      |
//| open trades (profit + swap + commission + fees).                 |
//+------------------------------------------------------------------+
double TodayPnL(const datetime dayStart, const datetime now)
  {
   double pnl = 0.0;
   if(HistorySelect(dayStart, now + 60))
     {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong deal = HistoryDealGetTicket(i);
         if(deal == 0)
            continue;
         if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
            continue;
         if((ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagic)
            continue;
         pnl += HistoryDealGetDouble(deal, DEAL_PROFIT)
              + HistoryDealGetDouble(deal, DEAL_SWAP)
              + HistoryDealGetDouble(deal, DEAL_COMMISSION)
              + HistoryDealGetDouble(deal, DEAL_FEE);
        }
     }
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(IsOurPosition(ticket))
         pnl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return(pnl);
  }

//+------------------------------------------------------------------+
//| Refresh the news window from the MT5 economic calendar, at most  |
//| once per minute. Calendar times are broker server time.          |
//+------------------------------------------------------------------+
void UpdateNewsWindow()
  {
   datetime now = TimeTradeServer();
   if(g_newsCheckTime != 0 && now - g_newsCheckTime < 60)
      return;
   g_newsCheckTime = now;

   string prevTitle = g_newsTitle;
   g_newsBlock    = false;
   g_newsUpcoming = false;
   g_newsTitle    = "";

   datetime from = now - InpNewsAfterMin * 60;
   datetime to   = now + InpNewsBeforeMin * 60;

   for(int c = 0; c < ArraySize(g_newsCurrencies); c++)
     {
      MqlCalendarValue values[];
      ResetLastError();
      if(!CalendarValueHistory(values, from, to, NULL, g_newsCurrencies[c]))
        {
         int err = GetLastError();
         if(err != 0)
            PrintFormat("News filter: calendar read failed for %s, error %d", g_newsCurrencies[c], err);
         continue;
        }
      for(int i = 0; i < ArraySize(values); i++)
        {
         MqlCalendarEvent ev;
         if(!CalendarEventById(values[i].event_id, ev))
            continue;
         bool important = (ev.importance == CALENDAR_IMPORTANCE_HIGH) ||
                          (InpNewsMedium && ev.importance == CALENDAR_IMPORTANCE_MODERATE);
         if(!important)
            continue;

         g_newsBlock = true;
         g_newsTitle = g_newsCurrencies[c] + " " + ev.name + " at " +
                       TimeToString(values[i].time, TIME_DATE | TIME_MINUTES);
         if(values[i].time >= now)
            g_newsUpcoming = true;
        }
     }

   if(g_newsBlock && g_newsTitle != prevTitle)
      Print("News filter active: ", g_newsTitle);
   else if(!g_newsBlock && prevTitle != "")
      Print("News filter cleared");
  }

//+------------------------------------------------------------------+
void CloseAll()
  {
   bool closedAny = false;
   ClosePositions(POSITION_TYPE_BUY,  closedAny);
   ClosePositions(POSITION_TYPE_SELL, closedAny);
  }

//+------------------------------------------------------------------+
//| +1 if the higher-timeframe %K is above %D, -1 if below, 0 if no  |
//| data. Uses the live (forming) higher-timeframe candle.            |
//+------------------------------------------------------------------+
int HtfTrend()
  {
   double k[], d[];
   if(CopyBuffer(g_htf, MAIN_LINE,   0, 1, k) != 1) return(0);
   if(CopyBuffer(g_htf, SIGNAL_LINE, 0, 1, d) != 1) return(0);
   if(k[0] > d[0]) return(1);
   if(k[0] < d[0]) return(-1);
   return(0);
  }

//+------------------------------------------------------------------+
//| ATR of the last closed candle on the signal timeframe.           |
//+------------------------------------------------------------------+
double AtrValue()
  {
   if(g_atr == INVALID_HANDLE)
      return(0.0);
   double a[];
   if(CopyBuffer(g_atr, 0, 1, 1, a) != 1)
      return(0.0);
   return(a[0]);
  }

//+------------------------------------------------------------------+
//| Move the stop loss to entry (+ spread) once a trade is           |
//| InpBreakEvenAtr x ATR in profit. Only ever tightens the stop.    |
//+------------------------------------------------------------------+
void ManageBreakEven()
  {
   if(InpBreakEvenAtr <= 0.0)
      return;
   double atr = AtrValue();
   if(atr <= 0.0)
      return;

   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread = ask - bid;
   double minDist = (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) + 1) * point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!IsOurPosition(ticket))
         continue;
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         double target = NormalizeDouble(open + spread, digits);
         if(bid - open >= InpBreakEvenAtr * atr && (sl == 0.0 || sl < target) && bid - target >= minDist)
           {
            if(trade.PositionModify(ticket, target, tp))
               PrintFormat("BUY #%I64u: stop moved to break-even %s", ticket, DoubleToString(target, digits));
           }
        }
      else
        {
         double target = NormalizeDouble(open - spread, digits);
         if(open - ask >= InpBreakEvenAtr * atr && (sl == 0.0 || sl > target) && target - ask >= minDist)
           {
            if(trade.PositionModify(ticket, target, tp))
               PrintFormat("SELL #%I64u: stop moved to break-even %s", ticket, DoubleToString(target, digits));
           }
        }
     }
  }

//+------------------------------------------------------------------+
bool IsOurPosition(const ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
      return(false);
   return(PositionGetString(POSITION_SYMBOL) == _Symbol &&
          (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic);
  }

//+------------------------------------------------------------------+
//| Close this EA's positions of one type. Returns false if any      |
//| close failed; closedAny reports whether something was closed.    |
//+------------------------------------------------------------------+
bool ClosePositions(const ENUM_POSITION_TYPE type, bool &closedAny)
  {
   bool ok = true;
   closedAny = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!IsOurPosition(ticket))
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type)
         continue;

      if(trade.PositionClose(ticket, InpSlippagePts))
        {
         closedAny = true;
         PrintFormat("Closed %s #%I64u",
                     type == POSITION_TYPE_BUY ? "BUY" : "SELL", ticket);
        }
      else
        {
         ok = false;
         PrintFormat("Close #%I64u failed: %d %s", ticket,
                     trade.ResultRetcode(), trade.ResultRetcodeDescription());
        }
     }
   return(ok);
  }

//+------------------------------------------------------------------+
//| Returns true only when a new position was opened.                |
//+------------------------------------------------------------------+
bool OpenPosition(const ENUM_ORDER_TYPE type)
  {
   //--- one position per direction at a time
   ENUM_POSITION_TYPE ptype = (type == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(IsOurPosition(ticket) && (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == ptype)
         return(false);
     }

   if(InpMaxSpreadPts > 0)
     {
      long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > InpMaxSpreadPts)
        {
         PrintFormat("Entry skipped: spread %I64d > max %d points", spread, InpMaxSpreadPts);
         return(false);
        }
     }

   double lots = NormalizeLots(InpLots);
   if(lots <= 0.0)
      return(false);

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double minDist = (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) + 1) * point;
   double slRaw = InpStopLossDist, tpRaw = InpTakeProfitDist;
   if(InpSlMode == SL_ATR)
     {
      double atr = AtrValue();
      if(atr <= 0.0)
        {
         Print("Entry skipped: ATR not ready");
         return(false);
        }
      slRaw = InpAtrSlMult * atr;
      tpRaw = InpAtrTpMult * atr;
     }
   double slDist = (slRaw > 0.0) ? MathMax(slRaw, minDist) : 0.0;
   double tpDist = (tpRaw > 0.0) ? MathMax(tpRaw, minDist) : 0.0;
   double price, sl = 0.0, tp = 0.0;

   if(type == ORDER_TYPE_BUY)
     {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(slDist > 0.0) sl = NormalizeDouble(price - slDist, digits);
      if(tpDist > 0.0) tp = NormalizeDouble(price + tpDist, digits);
      if(!trade.Buy(lots, _Symbol, price, sl, tp, InpComment))
        {
         PrintFormat("BUY failed: %d %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
         return(false);
        }
     }
   else
     {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(slDist > 0.0) sl = NormalizeDouble(price + slDist, digits);
      if(tpDist > 0.0) tp = NormalizeDouble(price - tpDist, digits);
      if(!trade.Sell(lots, _Symbol, price, sl, tp, InpComment))
        {
         PrintFormat("SELL failed: %d %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
         return(false);
        }
     }
   return(true);
  }

//+------------------------------------------------------------------+
double NormalizeLots(double lots)
  {
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(stepLot <= 0.0)
      stepLot = 0.01;
   lots = MathFloor(lots / stepLot + 1e-9) * stepLot;
   if(lots < minLot)
     {
      PrintFormat("Lot size %.2f is below broker minimum %.2f", InpLots, minLot);
      return(0.0);
     }
   return(MathMin(lots, maxLot));
  }
//+------------------------------------------------------------------+
