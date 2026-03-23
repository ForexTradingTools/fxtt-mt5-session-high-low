//+------------------------------------------------------------------+
//| fxtt-session-high-low.mq5                                        |
//| Copyright 2026, Carlos Oliveira                                  |
//| https://www.forextradingtools.eu                                 |
//|                                                                  |
//| Session High/Low — Draws H/L lines for Asia, Europe, New York.  |
//| Extras: background shading, daily H/L, toggle buttons.         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Carlos Oliveira"
#property link      "https://www.forextradingtools.eu/"
#property version   "2.20"
#property description "Session High/Low with daily H/L, background shading and toggle buttons"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Object-name prefix (bulk-delete stays surgical)
#define SHL_SES  "SHL_"    // Session lines, backgrounds, chart text labels

//--- Button object names (state stored in chart object itself, survives ticks)
#define BTN_LINES  "SHLB_LINES"
#define BTN_LABELS "SHLB_LABELS"
#define BTN_BG     "SHLB_BG"
#define BTN_DAILY  "SHLB_DAILY"

#define MAX_SESSIONS 3
#define BTN_W  190   // button width (px)
#define BTN_H   20   // button row height (px)

//+------------------------------------------------------------------+
//| Session identifiers                                              |
//+------------------------------------------------------------------+
enum ENUM_SID
  {
   SID_ASIA    = 0,  // Asia
   SID_EUROPE  = 1,  // Europe
   SID_NEWYORK = 2,  // New York
  };

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "=== General ==="
input int InpLookback  = 5;   // Sessions to Show
input int InpGmtOffset = 2;   // Broker GMT Offset (hours, e.g. 2 = GMT+2)

input group "=== Asia Session ==="
input bool            InpShowAsia      = true;
input int             InpAsiaStart     = 0;                 // Start Hour (GMT)
input int             InpAsiaEnd       = 9;                 // End Hour (GMT)
input color           InpAsiaHighColor = C'210,0,170';      // High Color
input color           InpAsiaLowColor  = C'210,0,170';      // Low Color
input color           InpAsiaBgColor   = clrGainsboro;      // Background Color
input ENUM_LINE_STYLE InpAsiaStyle     = STYLE_DASHDOTDOT;  // Historical Line Style
input int             InpAsiaWidth     = 1;                 // Line Width (px)

input group "=== Europe Session ==="
input bool            InpShowEurope      = true;
input int             InpEuropeStart     = 7;               // Start Hour (GMT)
input int             InpEuropeEnd       = 16;              // End Hour (GMT)
input color           InpEuropeHighColor = C'40,110,220';   // High Color
input color           InpEuropeLowColor  = C'40,110,220';   // Low Color
input color           InpEuropeBgColor   = clrGainsboro;    // Background Color
input ENUM_LINE_STYLE InpEuropeStyle     = STYLE_DASHDOTDOT;
input int             InpEuropeWidth     = 1;

input group "=== New York Session ==="
input bool            InpShowNewYork      = true;
input int             InpNewYorkStart     = 13;             // Start Hour (GMT)
input int             InpNewYorkEnd       = 22;             // End Hour (GMT)
input color           InpNewYorkHighColor = C'0,190,110';   // High Color
input color           InpNewYorkLowColor  = C'0,190,110';   // Low Color
input color           InpNewYorkBgColor   = clrGainsboro;   // Background Color
input ENUM_LINE_STYLE InpNewYorkStyle     = STYLE_DASHDOTDOT;
input int             InpNewYorkWidth     = 1;

input group "=== Daily High/Low ==="
input bool            InpShowDaily      = true;                // Show Daily High/Low
input color           InpDailyHighColor = C'255,200,50';       // High Color
input color           InpDailyLowColor  = C'255,200,50';       // Low Color
input ENUM_LINE_STYLE InpDailyStyle     = STYLE_DASH;          // Historical Line Style
input int             InpDailyWidth     = 1;                   // Line Width (px)

input group "=== Lines & Chart Labels ==="
input bool   InpExtendCurrent = false;        // Extend Current Session Lines Right
input string InpLabelFont     = "Segoe UI";  // Chart Label Font
input int    InpLabelSize     = 8;           // Chart Label Font Size (pts)

input group "=== Buttons ==="
input bool             InpShowButtons = true;               // Show Panel Buttons
input color            InpTextColor   = White;              // Text Color
input color            InpButtonColor = C'30,60,100';       // Button Background Color
input int              InpPanelX      = 10;                 // Button X Offset (px)
input int              InpPanelY      = 20;                 // Button Y Offset (px)
input ENUM_BASE_CORNER InpPanelCorner = CORNER_RIGHT_UPPER; // Button Corner

//+------------------------------------------------------------------+
//| Session configuration (populated from inputs at init)           |
//+------------------------------------------------------------------+
struct SConfig
  {
   string            name;
   bool              show;
   int               startHour;
   int               endHour;
   color             highColor;
   color             lowColor;
   color             bgColor;
   ENUM_LINE_STYLE   style;
   int               width;
  };

//+------------------------------------------------------------------+
//| One session occurrence (a single day's session window)          |
//+------------------------------------------------------------------+
struct SOccurrence
  {
   datetime  timeStart;
   datetime  timeEnd;
   double    high;
   double    low;
   double    open;
   bool      isOpen;
  };

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
SConfig  g_cfg[MAX_SESSIONS];
datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_cfg[SID_ASIA]    = MakeConfig("Asia",     InpShowAsia,    InpAsiaStart,    InpAsiaEnd,
                                   InpAsiaHighColor,    InpAsiaLowColor,    InpAsiaBgColor,
                                   InpAsiaStyle,    InpAsiaWidth);
   g_cfg[SID_EUROPE]  = MakeConfig("Europe",   InpShowEurope,  InpEuropeStart,  InpEuropeEnd,
                                   InpEuropeHighColor,  InpEuropeLowColor,  InpEuropeBgColor,
                                   InpEuropeStyle,  InpEuropeWidth);
   g_cfg[SID_NEWYORK] = MakeConfig("New York", InpShowNewYork, InpNewYorkStart, InpNewYorkEnd,
                                   InpNewYorkHighColor, InpNewYorkLowColor, InpNewYorkBgColor,
                                   InpNewYorkStyle, InpNewYorkWidth);
   CreateButtons();
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(reason == REASON_REMOVE)
     {
      ObjectsDeleteAll(0, SHL_SES);
      ObjectDelete(0, BTN_LINES);
      ObjectDelete(0, BTN_LABELS);
      ObjectDelete(0, BTN_BG);
      ObjectDelete(0, BTN_DAILY);
      ChartRedraw(0);
     }
  }

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int      rates_total,
                const int      prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
  {
   if(rates_total < 2)
      return 0;

   datetime barTime = time[rates_total - 1];
   if(prev_calculated == 0 || barTime != g_lastBarTime)
     {
      g_lastBarTime = barTime;
      Redraw();
     }
   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnChartEvent — handle toggle button clicks                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;
   if(sparam == BTN_LINES || sparam == BTN_LABELS || sparam == BTN_BG || sparam == BTN_DAILY)
      Redraw();
  }

//=============================================================================
//   Session logic
//=============================================================================

SConfig MakeConfig(const string name, bool show, int startH, int endH,
                   color hiClr, color loClr, color bgClr,
                   ENUM_LINE_STYLE style, int width)
  {
   SConfig c;
   c.name      = name;
   c.show      = show;
   c.startHour = startH;
   c.endHour   = endH;
   c.highColor = hiClr;
   c.lowColor  = loClr;
   c.bgColor   = bgClr;
   c.style     = style;
   c.width     = width;
   return c;
  }

//--- Convert broker server time → GMT
datetime ToGmt(datetime t) { return (datetime)((long)t - (long)InpGmtOffset * 3600); }

//--- GMT hour of a broker datetime
int GmtHour(datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(ToGmt(t), dt);
   return dt.hour;
  }

//--- True when gmtHour ∈ [startHour, endHour)  (handles midnight wrap)
bool IsInSession(int gmtHour, int startHour, int endHour)
  {
   if(startHour < endHour)
      return (gmtHour >= startHour && gmtHour < endHour);
   return (gmtHour >= startHour || gmtHour < endHour);   // midnight wrap
  }

//--- Scan history; return up to maxCount occurrences (oldest → newest)
void FindOccurrences(const SConfig &cfg, SOccurrence &result[], int maxCount)
  {
   ArrayResize(result, 0);

   int periodSecs = PeriodSeconds();
   int scanBars   = (maxCount + 2) * (int)(86400.0 / periodSecs) + 10;
   int totalBars  = Bars(_Symbol, _Period);
   if(scanBars > totalBars - 1) scanBars = totalBars - 1;
   if(scanBars < 2)             return;

   datetime times[];
   double   highs[], lows[], opens[];
   ArraySetAsSeries(times, false);
   ArraySetAsSeries(highs, false);
   ArraySetAsSeries(lows,  false);
   ArraySetAsSeries(opens, false);

   if(CopyTime(_Symbol, _Period, 0, scanBars, times) <= 0) return;
   if(CopyHigh(_Symbol, _Period, 0, scanBars, highs) <= 0) return;
   if(CopyLow (_Symbol, _Period, 0, scanBars, lows)  <= 0) return;
   if(CopyOpen(_Symbol, _Period, 0, scanBars, opens)  <= 0) return;

   int         n         = ArraySize(times);
   bool        inSession = false;
   SOccurrence cur;
   ZeroMemory(cur);

   for(int i = 0; i < n; i++)
     {
      bool active = IsInSession(GmtHour(times[i]), cfg.startHour, cfg.endHour);

      if(!inSession && active)
        {
         cur.timeStart = times[i];
         cur.timeEnd   = times[i];
         cur.high      = highs[i];
         cur.low       = lows[i];
         cur.open      = opens[i];
         cur.isOpen    = false;
         inSession     = true;
        }
      else if(inSession && active)
        {
         cur.timeEnd = times[i];
         if(highs[i] > cur.high) cur.high = highs[i];
         if(lows[i]  < cur.low)  cur.low  = lows[i];
        }
      else if(inSession && !active)
        {
         int sz = ArraySize(result);
         ArrayResize(result, sz + 1);
         result[sz] = cur;
         inSession   = false;
        }
     }

   if(inSession)
     {
      cur.isOpen = true;
      int sz = ArraySize(result);
      ArrayResize(result, sz + 1);
      result[sz] = cur;
     }

   int total = ArraySize(result);
   if(total > maxCount)
     {
      int skip = total - maxCount;
      for(int i = 0; i < maxCount; i++)
         result[i] = result[i + skip];
      ArrayResize(result, maxCount);
     }
  }

//=============================================================================
//   Chart drawing helpers
//=============================================================================

void DrawLine(const string name, const datetime t1, const datetime t2,
              const double price, const color clr,
              const ENUM_LINE_STYLE style, const int width, const bool rayRight)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);

   ObjectSetInteger(0, name, OBJPROP_TIME,       0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE,      0, price);
   ObjectSetInteger(0, name, OBJPROP_TIME,       1, t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE,      1, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE,      style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT,  rayRight);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT,   false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED,   false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, name, OBJPROP_BACK,       true);
  }

void DrawBackground(const string name,
                    const datetime t1, const datetime t2,
                    const double hi, const double lo, const color clr)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, hi, t2, lo);

   ObjectSetInteger(0, name, OBJPROP_TIME,       0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE,      0, hi);
   ObjectSetInteger(0, name, OBJPROP_TIME,       1, t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE,      1, lo);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE,      STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      1);
   ObjectSetInteger(0, name, OBJPROP_FILL,       true);
   ObjectSetInteger(0, name, OBJPROP_BACK,       true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED,   false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
  }

void DrawChartText(const string name, const datetime t, const double price,
                   const string text, const color clr,
                   const ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);

   ObjectSetInteger(0, name, OBJPROP_TIME,       t);
   ObjectSetDouble (0, name, OBJPROP_PRICE,      price);
   ObjectSetString (0, name, OBJPROP_TEXT,       text);
   ObjectSetString (0, name, OBJPROP_FONT,       InpLabelFont);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   InpLabelSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,     anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED,   false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
  }

//--- Unique base name for a session occurrence's objects
string OccBase(int sid, datetime startTime)
  {
   return SHL_SES + IntegerToString(sid) + "_" + IntegerToString((long)startTime);
  }

string FmtPrice(double price) { return DoubleToString(price, _Digits); }

//--- Draw one session occurrence (background + lines + chart labels)
void DrawOccurrence(int sid, const SConfig &cfg, const SOccurrence &occ, int idxBack)
  {
   string base     = OccBase(sid, occ.timeStart);
   bool   rayRight = occ.isOpen && InpExtendCurrent;
   bool   showLines = !GetBtnState(BTN_LINES);
   bool   showLbls  = !GetBtnState(BTN_LABELS);
   bool   showBg    = !GetBtnState(BTN_BG);

   if(showBg)
     {
      int      pad   = occ.isOpen ? PeriodSeconds() * 3 : PeriodSeconds();
      datetime bgEnd = occ.timeEnd + (datetime)pad;
      DrawBackground(base + "_BG", occ.timeStart, bgEnd, occ.high, occ.low, cfg.bgColor);
     }

   if(showLines)
     {
      ENUM_LINE_STYLE ls = occ.isOpen ? STYLE_SOLID : cfg.style;
      int             lw = occ.isOpen ? MathMax(cfg.width, 1) : cfg.width;
      DrawLine(base + "_H", occ.timeStart, occ.timeEnd, occ.high, cfg.highColor, ls, lw, rayRight);
      DrawLine(base + "_L", occ.timeStart, occ.timeEnd, occ.low,  cfg.lowColor,  ls, lw, rayRight);
     }

   if(showLbls)
     {
      datetime lineEnd = occ.isOpen ? occ.timeEnd : occ.timeEnd + (datetime)PeriodSeconds();
      datetime lblTime = occ.timeStart + (datetime)((long)(lineEnd - occ.timeStart) / 2);
      string   tag     = idxBack > 0 ? " #" + IntegerToString(idxBack) + " " : " ";
      DrawChartText(base + "_LH", lblTime, occ.high, cfg.name + tag + FmtPrice(occ.high), cfg.highColor, ANCHOR_LOWER);
      DrawChartText(base + "_LL", lblTime, occ.low,  cfg.name + tag + FmtPrice(occ.low),  cfg.lowColor,  ANCHOR_UPPER);
     }
  }

//--- Draw daily high/low lines + labels for the last InpLookback broker days.
//    Uses PERIOD_D1 directly — one authoritative bar per calendar day.
void DrawDailyHL()
  {
   if(!InpShowDaily || GetBtnState(BTN_DAILY))
      return;

   //--- Fetch one extra bar so past day N has a known end time (= day N+1 open)
   int count = InpLookback + 1;

   datetime times[];
   double   highs[], lows[];
   ArraySetAsSeries(times, false);
   ArraySetAsSeries(highs, false);
   ArraySetAsSeries(lows,  false);

   if(CopyTime(_Symbol, PERIOD_D1, 0, count, times) <= 0) return;
   if(CopyHigh(_Symbol, PERIOD_D1, 0, count, highs) <= 0) return;
   if(CopyLow (_Symbol, PERIOD_D1, 0, count, lows)  <= 0) return;

   int n = ArraySize(times);

   // Skip the oldest bar — it exists only to provide the end-time for the next one
   int firstDrawable = (n == count) ? 1 : 0;

   for(int i = firstDrawable; i < n; i++)
     {
      bool     isToday  = (i == n - 1);
      datetime dayStart = times[i];
      // Past days end at the next day's open; today ends at the current bar (ray extends right)
      datetime dayEnd   = isToday ? (datetime)iTime(_Symbol, _Period, 0) : times[i + 1];

      bool     rayRight = isToday && InpExtendCurrent;
      string   base     = SHL_SES + "D_" + IntegerToString((long)dayStart);
      int      idxBack  = (n - 1) - i;   // 0 = today, 1 = yesterday, ...
      string   tag      = idxBack > 0 ? " #" + IntegerToString(idxBack) + " " : " ";

      ENUM_LINE_STYLE ls = isToday ? STYLE_SOLID : InpDailyStyle;

      DrawLine(base + "_H", dayStart, dayEnd, highs[i], InpDailyHighColor, ls, InpDailyWidth, rayRight);
      DrawLine(base + "_L", dayStart, dayEnd, lows[i],  InpDailyLowColor,  ls, InpDailyWidth, rayRight);

      //--- Label at the horizontal midpoint: high label sits above the line, low below
      datetime lblTime = dayStart + (datetime)((long)(dayEnd - dayStart) / 2);
      DrawChartText(base + "_LH", lblTime, highs[i], "Day" + tag + FmtPrice(highs[i]), InpDailyHighColor, ANCHOR_LOWER);
      DrawChartText(base + "_LL", lblTime, lows[i],  "Day" + tag + FmtPrice(lows[i]),  InpDailyLowColor,  ANCHOR_UPPER);
     }
  }

//--- Full redraw: scan all sessions and draw objects
void Redraw()
  {
   ObjectsDeleteAll(0, SHL_SES);

   for(int sid = 0; sid < MAX_SESSIONS; sid++)
     {
      if(!g_cfg[sid].show)
         continue;

      SOccurrence occs[];
      FindOccurrences(g_cfg[sid], occs, InpLookback);
      int total = ArraySize(occs);
      if(total == 0)
         continue;

      for(int i = 0; i < total; i++)
         DrawOccurrence(sid, g_cfg[sid], occs[i], (total - 1) - i);
     }

   DrawDailyHL();
   PaintButtons();
   ChartRedraw(0);
  }

//=============================================================================
//   Button helpers
//=============================================================================

bool GetBtnState(const string name)
  {
   return (bool)(int)ObjectGetInteger(0, name, OBJPROP_STATE);
  }

//--- Create the toggle buttons once (state persists in the chart object).
//    BTN_BG starts pressed (state=true) so background is hidden by default.
void CreateButtons()
  {
   string btns[] = {BTN_LINES, BTN_LABELS, BTN_BG, BTN_DAILY};
   for(int i = 0; i < ArraySize(btns); i++)
      if(ObjectFind(0, btns[i]) < 0)
        {
         ObjectCreate(0, btns[i], OBJ_BUTTON, 0, 0, 0, 0, 0);
         if(btns[i] == BTN_BG)
            ObjectSetInteger(0, BTN_BG, OBJPROP_STATE, true);
        }
  }

//--- Resolve pixel X for button column (accounts for right-side corners)
int ButtonX()
  {
   return (InpPanelCorner == CORNER_RIGHT_UPPER || InpPanelCorner == CORNER_RIGHT_LOWER)
          ? BTN_W + InpPanelX : InpPanelX;
  }

void PaintButton(const string name, const string caption, int y)
  {
   ObjectSetString (0, name, OBJPROP_TEXT,       caption);
   ObjectSetString (0, name, OBJPROP_FONT,       "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   9);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      InpTextColor);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    InpButtonColor);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  ButtonX());
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,      BTN_W);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,      BTN_H - 2);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     InpPanelCorner);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  }

void PaintButtons()
  {
   if(!InpShowButtons)
     {
      //--- Collapse buttons to zero size so they are invisible but their toggle
      //    state is preserved (important for BTN_BG which starts pressed = bg hidden)
      string btns[] = {BTN_LINES, BTN_LABELS, BTN_BG, BTN_DAILY};
      for(int i = 0; i < ArraySize(btns); i++)
        {
         if(ObjectFind(0, btns[i]) >= 0)
           {
            ObjectSetInteger(0, btns[i], OBJPROP_XSIZE, 0);
            ObjectSetInteger(0, btns[i], OBJPROP_YSIZE, 0);
           }
        }
      return;
     }

   int pos = InpPanelY;
   PaintButton(BTN_LINES,  !GetBtnState(BTN_LINES)  ? "Hide Lines"      : "Show Lines",      pos); pos += BTN_H;
   PaintButton(BTN_LABELS, !GetBtnState(BTN_LABELS) ? "Hide Labels"     : "Show Labels",     pos); pos += BTN_H;
   PaintButton(BTN_BG,     !GetBtnState(BTN_BG)     ? "Hide Background" : "Show Background", pos); pos += BTN_H;
   PaintButton(BTN_DAILY,  !GetBtnState(BTN_DAILY)  ? "Hide Daily H/L"  : "Show Daily H/L",  pos);
  }
//+------------------------------------------------------------------+
