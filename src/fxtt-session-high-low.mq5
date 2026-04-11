//+------------------------------------------------------------------+
//| fxtt-session-high-low.mq5                                        |
//| Copyright 2026, Carlos Oliveira                                  |
//| https://www.forextradingtools.eu                                 |
//|                                                                  |
//| Session High/Low — Draws H/L lines for Asia, Europe, New York.  |
//| Extras: background shading, daily H/L, toggle panel.            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Carlos Oliveira"
#property link      "https://www.forextradingtools.eu/"
#property version   "3.10"
#property description "Session High/Low with daily H/L, background shading and toggle panel"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include "CSessionHighLow.mqh"

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
input bool            InpShowDaily      = false;             // Show Daily High/Low
input color           InpDailyHighColor = C'255,200,50';    // High Color
input color           InpDailyLowColor  = C'255,200,50';    // Low Color
input ENUM_LINE_STYLE InpDailyStyle     = STYLE_DASH;       // Historical Line Style
input int             InpDailyWidth     = 1;                // Line Width (px)

input group "=== Lines & Chart Labels ==="
input bool   InpExtendCurrent = false;       // Extend Current Session Lines Right
input string InpLabelFont     = "Segoe UI"; // Chart Label Font
input int    InpLabelSize     = 8;          // Chart Label Font Size (pts)

input group "=== Panel ==="
input bool             InpShowPanel             = true;               // Show Toggle Panel
input int              InpPanelX                = 10;                 // Panel X Offset (px)
input int              InpPanelY                = 20;                 // Panel Y Offset (px)
input ENUM_BASE_CORNER InpPanelCorner           = CORNER_RIGHT_UPPER; // Initial Panel Corner
input color            InpPanelBgColor          = C'25,25,25';       // Panel Background
input color            InpPanelAccentColor      = C'30,60,100';      // Panel Accent / Checked Color
input color            InpPanelTextColor        = clrWhite;          // Panel Text Color
input int              InpPanelFontSize         = 9;                 // Panel Font Size
input bool             InpPersistPanelPos       = true;              // Persist Dragged Position
input bool             InpPersistCheckedRows    = true;              // Persist Checked Rows

input group "=== Panel Layout ==="
input int              InpPanelWidth            = 190;               // Panel Width
input int              InpPanelToggleHeight     = 26;                // Title Height
input int              InpPanelRowHeight        = 24;                // Row Height
input int              InpPanelCheckboxSize     = 16;                // Checkbox Size
input int              InpPanelPaddingX         = 8;                 // Horizontal Padding
input int              InpPanelPaddingH         = 6;                 // Vertical Padding
input string           InpPanelTitle            = "Sessions";        // Panel Title

input group "=== Timeframe Background ==="
input bool            InpTFBgEnabled   = true;          // Enable Timeframe Background
input ENUM_TIMEFRAMES InpTFBgTimeframe = PERIOD_D1;     // Desired Timeframe
input int             InpTFBgLookback  = 5;             // Candles to Show
input color           InpChartBgColor  = clrGainsboro;  // Chart Background Color
input color           InpTFBodyColor   = clrWhite;      // Candle Body Color
input color           InpTFWickColor   = clrWhiteSmoke; // Candle Wick Color

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
CSessionHighLow g_shl;
datetime        g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SSessionHLSettings s;
   s.gmtOffset = InpGmtOffset;
   s.lookback  = InpLookback;
   s.objPrefix = "SHL_";

   //--- Sessions
   SSessionConfig ses;

   ses.name = "Asia";     ses.show = InpShowAsia;    ses.startHour = InpAsiaStart;
   ses.endHour = InpAsiaEnd; ses.highColor = InpAsiaHighColor; ses.lowColor = InpAsiaLowColor;
   ses.bgColor = InpAsiaBgColor; ses.style = InpAsiaStyle; ses.width = InpAsiaWidth;
   s.sessions[0] = ses;

   ses.name = "Europe";   ses.show = InpShowEurope;  ses.startHour = InpEuropeStart;
   ses.endHour = InpEuropeEnd; ses.highColor = InpEuropeHighColor; ses.lowColor = InpEuropeLowColor;
   ses.bgColor = InpEuropeBgColor; ses.style = InpEuropeStyle; ses.width = InpEuropeWidth;
   s.sessions[1] = ses;

   ses.name = "New York"; ses.show = InpShowNewYork; ses.startHour = InpNewYorkStart;
   ses.endHour = InpNewYorkEnd; ses.highColor = InpNewYorkHighColor; ses.lowColor = InpNewYorkLowColor;
   ses.bgColor = InpNewYorkBgColor; ses.style = InpNewYorkStyle; ses.width = InpNewYorkWidth;
   s.sessions[2] = ses;

   //--- Daily H/L
   s.showDaily      = InpShowDaily;
   s.dailyHighColor = InpDailyHighColor;
   s.dailyLowColor  = InpDailyLowColor;
   s.dailyStyle     = InpDailyStyle;
   s.dailyWidth     = InpDailyWidth;

   //--- Lines & labels
   s.extendCurrent = InpExtendCurrent;
   s.labelFont     = InpLabelFont;
   s.labelSize     = InpLabelSize;

   //--- Panel
   s.showPanel          = InpShowPanel;
   s.panelBgColor       = InpPanelBgColor;
   s.panelAccentColor   = InpPanelAccentColor;
   s.panelTextColor     = InpPanelTextColor;
   s.panelFontSize      = InpPanelFontSize;
   s.panelX             = InpPanelX;
   s.panelY             = InpPanelY;
   s.panelCorner        = InpPanelCorner;
   s.panelWidth         = InpPanelWidth;
   s.panelToggleHeight  = InpPanelToggleHeight;
   s.panelRowHeight     = InpPanelRowHeight;
   s.panelCheckboxSize  = InpPanelCheckboxSize;
   s.panelPadX          = InpPanelPaddingX;
   s.panelPadH          = InpPanelPaddingH;
   s.persistPanelPos    = InpPersistPanelPos;
   s.persistCheckedRows = InpPersistCheckedRows;
   s.panelTitle         = InpPanelTitle;

   //--- TF background
   s.tfBgEnabled   = InpTFBgEnabled;
   s.tfBgTimeframe = InpTFBgTimeframe;
   s.tfBgLookback  = InpTFBgLookback;
   s.chartBgColor  = InpChartBgColor;
   s.tfBodyColor   = InpTFBodyColor;
   s.tfWickColor   = InpTFWickColor;

   return g_shl.Init(s) ? INIT_SUCCEEDED : INIT_FAILED;
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_shl.Deinit(reason);
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
      g_shl.Redraw();
     }
   return rates_total;
  }

//+------------------------------------------------------------------+
//| OnChartEvent - forward chart UI events to the session engine    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   g_shl.OnChartEvent(id, lparam, dparam, sparam);
  }
//+------------------------------------------------------------------+
