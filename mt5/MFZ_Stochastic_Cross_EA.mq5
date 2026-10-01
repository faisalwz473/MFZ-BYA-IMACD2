//+------------------------------------------------------------------+
//|                                     MFZ_Stochastic_Cross_EA.mq5 |
//|  Stochastic (21, 3, 5) %K / %D crossover Expert Advisor for MT5  |
//|                                                                  |
//|  Rules (evaluated on the CLOSED bar of the signal timeframe, M5):|
//|   - %K crosses UP   %D -> close SELL (take profit) + open BUY    |
//|   - %K crosses DOWN %D -> close BUY  (take profit) + open SELL   |
//+------------------------------------------------------------------+
#property copyright "MFZ"
#property version   "1.00"

#include <Trade\Trade.mqh>

enum ENUM_TRADE_DIRECTION
  {
   DIR_BOTH      = 0, // Buy and Sell
   DIR_BUY_ONLY  = 1, // Buy only
   DIR_SELL_ONLY = 2  // Sell only
  };

//--- Signal
input group "Stochastic signal"
input ENUM_TIMEFRAMES InpTimeframe   = PERIOD_M5;    // Signal timeframe
input int             InpKPeriod     = 21;           // %K period
input int             InpDPeriod     = 3;            // %D period
input int             InpSlowing     = 5;            // Slowing
input ENUM_MA_METHOD  InpMaMethod    = MODE_SMA;     // MA method
input ENUM_STO_PRICE  InpPriceField  = STO_LOWHIGH;  // Price field

//--- Trading
input group "Trading"
input ENUM_TRADE_DIRECTION InpDirection = DIR_BOTH;  // Trade direction
input double          InpLots        = 0.01;         // Lot size
input int             InpStopLossPts = 0;            // Safety stop loss in points (0 = off)
input int             InpTakeProfitPts = 0;          // Safety take profit in points (0 = off, exit on cross)
input bool            InpReverse     = true;         // Open the opposite trade on the same cross that exits
input int             InpMaxSpreadPts = 0;           // Max spread in points for new entries (0 = off)
input int             InpSlippagePts = 20;           // Max slippage in points
input ulong           InpMagic       = 21305;        // Magic number
input string          InpComment     = "MFZ Stoch 21-3-5"; // Order comment

//--- Globals
CTrade   trade;
int      g_stoch = INVALID_HANDLE;
datetime g_lastBarTime = 0;

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

   g_stoch = iStochastic(_Symbol, InpTimeframe, InpKPeriod, InpDPeriod, InpSlowing,
                         InpMaMethod, InpPriceField);
   if(g_stoch == INVALID_HANDLE)
     {
      PrintFormat("Failed to create Stochastic handle, error %d", GetLastError());
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePts);
   trade.SetTypeFillingBySymbol(_Symbol);

   // Do not trade the bar that is already closed when the EA is attached.
   g_lastBarTime = iTime(_Symbol, InpTimeframe, 0);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_stoch != INVALID_HANDLE)
      IndicatorRelease(g_stoch);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   //--- act once per new bar of the signal timeframe
   datetime barTime = iTime(_Symbol, InpTimeframe, 0);
   if(barTime == 0 || barTime == g_lastBarTime)
      return;

   int signal = 0;
   if(!GetCrossSignal(signal))
      return; // data not ready yet - retry on the next tick

   g_lastBarTime = barTime;
   if(signal == 0)
      return;

   bool closedAny = false;
   if(signal > 0)   // %K crossed UP through %D
     {
      // TP for sells; never open a buy while a sell failed to close
      if(!ClosePositions(POSITION_TYPE_SELL, closedAny))
         return;
      if(InpDirection != DIR_SELL_ONLY && (InpReverse || !closedAny))
         OpenPosition(ORDER_TYPE_BUY);
     }
   else             // %K crossed DOWN through %D
     {
      // TP for buys; never open a sell while a buy failed to close
      if(!ClosePositions(POSITION_TYPE_BUY, closedAny))
         return;
      if(InpDirection != DIR_BUY_ONLY && (InpReverse || !closedAny))
         OpenPosition(ORDER_TYPE_SELL);
     }
  }

//+------------------------------------------------------------------+
//| +1 = %K crossed up %D on the last closed bar, -1 = crossed down  |
//| Uses closed bars only, so the signal never repaints.             |
//+------------------------------------------------------------------+
bool GetCrossSignal(int &signal)
  {
   signal = 0;
   const int depth = 12;
   double k[], d[];
   ArraySetAsSeries(k, true);
   ArraySetAsSeries(d, true);

   if(CopyBuffer(g_stoch, MAIN_LINE,   0, depth, k) != depth) return(false);
   if(CopyBuffer(g_stoch, SIGNAL_LINE, 0, depth, d) != depth) return(false);

   double curr = k[1] - d[1];             // last closed bar
   if(curr == 0.0)
      return(true);                       // touching, not crossed yet

   // previous non-zero difference (handles bars where %K == %D exactly)
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
         PrintFormat("Closed %s #%I64u on Stochastic cross",
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
void OpenPosition(const ENUM_ORDER_TYPE type)
  {
   //--- one position per direction at a time
   ENUM_POSITION_TYPE ptype = (type == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(IsOurPosition(ticket) && (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == ptype)
         return;
     }

   if(InpMaxSpreadPts > 0)
     {
      long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > InpMaxSpreadPts)
        {
         PrintFormat("Entry skipped: spread %I64d > max %d points", spread, InpMaxSpreadPts);
         return;
        }
     }

   double lots = NormalizeLots(InpLots);
   if(lots <= 0.0)
      return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double price, sl = 0.0, tp = 0.0;

   if(type == ORDER_TYPE_BUY)
     {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(InpStopLossPts   > 0) sl = NormalizeDouble(price - InpStopLossPts   * point, digits);
      if(InpTakeProfitPts > 0) tp = NormalizeDouble(price + InpTakeProfitPts * point, digits);
      if(!trade.Buy(lots, _Symbol, price, sl, tp, InpComment))
         PrintFormat("BUY failed: %d %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
     }
   else
     {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(InpStopLossPts   > 0) sl = NormalizeDouble(price + InpStopLossPts   * point, digits);
      if(InpTakeProfitPts > 0) tp = NormalizeDouble(price - InpTakeProfitPts * point, digits);
      if(!trade.Sell(lots, _Symbol, price, sl, tp, InpComment))
         PrintFormat("SELL failed: %d %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
     }
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
