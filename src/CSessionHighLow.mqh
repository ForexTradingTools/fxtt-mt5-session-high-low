//+------------------------------------------------------------------+
//| CSessionHighLow.mqh                                              |
//| Copyright 2026, Carlos Oliveira                                  |
//| https://www.forextradingtools.eu                                 |
//|                                                                  |
//| Reusable Session High/Low engine.  Handles session detection,   |
//| chart drawing (lines, labels, backgrounds), daily H/L,          |
//| timeframe background, and a reusable toggle panel.               |
//|                                                                  |
//| Minimal usage in another indicator:                              |
//|   #include <FxTT/SessionHighLow/CSessionHighLow.mqh>            |
//|   CSessionHighLow g_shl;                                         |
//|   int  OnInit()    { SSessionHLSettings s; /* populate s */      |
//|                       return g_shl.Init(s) ? INIT_SUCCEEDED      |
//|                                            : INIT_FAILED; }      |
//|   void OnDeinit(const int r) { g_shl.Deinit(r); }               |
//|   int  OnCalculate(...) { g_shl.Redraw(); return rates_total; }  |
//|   void OnChartEvent(...) { g_shl.OnChartEvent(id,lp,dp,sp); }   |
//|                                                                  |
//| To consume only session data (no drawing), call GetOccurrences() |
//| and draw the result yourself.                                    |
//+------------------------------------------------------------------+
#ifndef __FXTT_CSESSIONHIGHLOW_MQH__
#define __FXTT_CSESSIONHIGHLOW_MQH__

#include <FxTT/V1.000/UiTogglePanel.mqh>

#define SHL_MAX_SESSIONS 3
#define SHL_PANEL_ROW_COUNT 4

enum ENUM_SHL_PANEL_ROW
  {
   SHL_PANEL_LINES = 0,
   SHL_PANEL_LABELS,
   SHL_PANEL_BACKGROUND,
   SHL_PANEL_DAILY
  };

//+------------------------------------------------------------------+
//| Session configuration                                            |
//+------------------------------------------------------------------+
struct SSessionConfig
  {
   string            name;
   bool              show;
   int               startHour;      // Session open  (GMT hour, inclusive)
   int               endHour;        // Session close (GMT hour, exclusive)
   color             highColor;
   color             lowColor;
   color             bgColor;
   ENUM_LINE_STYLE   style;          // Historical (closed session) line style
   int               width;          // Line width (px)
  };

//+------------------------------------------------------------------+
//| One session occurrence (a single day's session window)          |
//+------------------------------------------------------------------+
struct SSessionOccurrence
  {
   datetime  timeStart;
   datetime  timeEnd;
   double    high;
   double    low;
   double    open;
   bool      isOpen;   // true = session is still in progress
  };

//+------------------------------------------------------------------+
//| Full indicator settings — populate from inputs, then pass to    |
//| CSessionHighLow::Init().                                         |
//+------------------------------------------------------------------+
struct SSessionHLSettings
  {
   //--- General
   int               gmtOffset;          // Broker GMT offset (hours)
   int               lookback;           // Session occurrences to show

   //--- Sessions (up to SHL_MAX_SESSIONS, indexed 0..2)
   SSessionConfig    sessions[SHL_MAX_SESSIONS];

   //--- Daily H/L
   bool              showDaily;
   color             dailyHighColor;
   color             dailyLowColor;
   ENUM_LINE_STYLE   dailyStyle;
   int               dailyWidth;

   //--- Lines & chart labels
   bool              extendCurrent;      // Extend current session lines right
   string            labelFont;
   int               labelSize;

   //--- Toggle panel
   bool              showPanel;
   color             panelBgColor;
   color             panelAccentColor;
   color             panelTextColor;
   int               panelFontSize;
   int               panelX;
   int               panelY;
   ENUM_BASE_CORNER  panelCorner;         // Used only for initial placement
   int               panelWidth;
   int               panelToggleHeight;
   int               panelRowHeight;
   int               panelCheckboxSize;
   int               panelPadX;
   int               panelPadH;
   bool              persistPanelPos;
   bool              persistCheckedRows;
   string            panelTitle;

   //--- Timeframe background
   bool              tfBgEnabled;
   ENUM_TIMEFRAMES   tfBgTimeframe;
   int               tfBgLookback;
   color             chartBgColor;
   color             tfBodyColor;
   color             tfWickColor;

   //--- Object-name prefix (change to avoid collisions when multiple
   //    instances of the class live on the same chart)
   string            objPrefix;          // e.g. "SHL_"
  };

//+------------------------------------------------------------------+
//| CSessionHighLow                                                  |
//+------------------------------------------------------------------+
class CSessionHighLow
  {
private:
   SSessionHLSettings m_s;

   string             m_drawPrefix;
   string             m_panelPrefix;
   string             m_tfbOrigBg;
   CTogglePanel       m_panel;
   bool               m_panelInitialized;

   //--- Time helpers
   datetime           ToGmt(datetime t)                              const;
   int                GmtHour(datetime t)                            const;
   bool               IsInSession(int gmtHour, int start, int end)   const;

   //--- Session scan (pure — no drawing side-effects)
   void               FindOccurrences(const SSessionConfig &cfg,
                                      SSessionOccurrence   &result[],
                                      int                   maxCount) const;

   //--- Chart object helpers
   void               DrawLine(const string name,
                                datetime t1, datetime t2,
                                double price, color clr,
                                ENUM_LINE_STYLE style, int width,
                                bool rayRight)                        const;
   void               DrawBackground(const string name,
                                      datetime t1, datetime t2,
                                      double hi, double lo,
                                      color clr)                      const;
   void               DrawChartText(const string name,
                                     datetime t, double price,
                                     const string text, color clr,
                                     ENUM_ANCHOR_POINT anchor
                                       = ANCHOR_LEFT)                 const;
   bool               IsPanelRowEnabled(const int row)               const;
   bool               ShowSessionBackgrounds()                       const;
   bool               ShowTimeframeBackground()                      const;
   void               ApplyChartBackgroundColor()                    const;
   string             OccBase(int sid, datetime startTime)            const;
   string             FmtPrice(double price)                          const;
   string             PanelPersistKey()                               const;
   string             PanelStateKey(const int row)                    const;
   bool               HasPersistedPanelStates()                       const;
   int                ResolvePanelX()                                 const;
   int                ResolvePanelY()                                 const;
   STogglePanelConfig BuildPanelConfig()                              const;
   void               InitPanel();
   void               ApplyDefaultPanelState();

   //--- High-level drawing
   void               DrawOccurrence(int sid,
                                      const SSessionConfig    &cfg,
                                      const SSessionOccurrence &occ,
                                      int idxBack)                    const;
   void               DrawDailyHL()                                   const;
   void               DrawTimeframeBg()                               const;

   //--- TF background lifecycle
   void               InitTFBackground();

public:
                      CSessionHighLow();

   bool               Init(const SSessionHLSettings &settings);
   void               Deinit(int reason);
   void               Redraw();
   void               OnChartEvent(int id, long lparam,
                                    double dparam, string sparam);

   //--- Exposes raw session data to external consumers (no drawing)
   void               GetOccurrences(int sid,
                                      SSessionOccurrence &result[],
                                      int maxCount)                   const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSessionHighLow::CSessionHighLow()
  : m_panelInitialized(false)
  {
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CSessionHighLow::Init(const SSessionHLSettings &settings)
  {
   m_s = settings;
   m_drawPrefix  = m_s.objPrefix + "DRAW_";
   m_panelPrefix = m_s.objPrefix + "PANEL_";
   m_tfbOrigBg   = m_s.objPrefix + "META_TFB_ORIGBG";

   InitTFBackground();
   InitPanel();
   return true;
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void CSessionHighLow::Deinit(int reason)
  {
   if(m_panelInitialized)
     {
      m_panel.Destroy();
      m_panelInitialized = false;
     }

   if(ObjectFind(0, m_tfbOrigBg) >= 0)
     {
      color origBg = (color)ObjectGetInteger(0, m_tfbOrigBg, OBJPROP_COLOR);
      ChartSetInteger(0, CHART_COLOR_BACKGROUND, origBg);
      if(reason == REASON_REMOVE)
         ObjectDelete(0, m_tfbOrigBg);
     }

   ObjectsDeleteAll(0, m_drawPrefix);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Redraw — full repaint of all chart objects                      |
//+------------------------------------------------------------------+
void CSessionHighLow::Redraw()
  {
   ObjectsDeleteAll(0, m_drawPrefix);

   DrawTimeframeBg();   // draw first - sits furthest behind everything

   for(int sid = 0; sid < SHL_MAX_SESSIONS; sid++)
     {
      if(!m_s.sessions[sid].show)
         continue;

      SSessionOccurrence occs[];
      FindOccurrences(m_s.sessions[sid], occs, m_s.lookback);
      int total = ArraySize(occs);

      for(int i = 0; i < total; i++)
         DrawOccurrence(sid, m_s.sessions[sid], occs[i], (total - 1) - i);
     }

   DrawDailyHL();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| OnChartEvent — handle toggle button clicks                      |
//+------------------------------------------------------------------+
void CSessionHighLow::OnChartEvent(int id, long lparam, double dparam, string sparam)
  {
   if(m_panelInitialized && m_panel.OnChartEvent(id, lparam, dparam, sparam))
     {
      int  row = -1;
      bool enabled = false;
      if(m_panel.ConsumeToggleEvent(row, enabled))
         Redraw();
      return;
     }
  }

//+------------------------------------------------------------------+
//| GetOccurrences — public, for external consumers                 |
//+------------------------------------------------------------------+
void CSessionHighLow::GetOccurrences(int sid, SSessionOccurrence &result[], int maxCount) const
  {
   if(sid < 0 || sid >= SHL_MAX_SESSIONS)
     { ArrayResize(result, 0); return; }
   FindOccurrences(m_s.sessions[sid], result, maxCount);
  }

//=============================================================================
//   Time helpers
//=============================================================================

datetime CSessionHighLow::ToGmt(datetime t) const
  {
   return (datetime)((long)t - (long)m_s.gmtOffset * 3600);
  }

int CSessionHighLow::GmtHour(datetime t) const
  {
   MqlDateTime dt;
   TimeToStruct(ToGmt(t), dt);
   return dt.hour;
  }

//--- True when gmtHour ∈ [start, end)  — handles midnight wrap
bool CSessionHighLow::IsInSession(int gmtHour, int start, int end) const
  {
   if(start < end)
      return (gmtHour >= start && gmtHour < end);
   return (gmtHour >= start || gmtHour < end);
  }

//=============================================================================
//   Session scan
//=============================================================================

void CSessionHighLow::FindOccurrences(const SSessionConfig &cfg,
                                       SSessionOccurrence   &result[],
                                       int                   maxCount) const
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

   int                n         = ArraySize(times);
   bool               inSession = false;
   SSessionOccurrence cur;
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

   //--- Keep only the most recent maxCount occurrences
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
//   Chart object helpers
//=============================================================================

void CSessionHighLow::DrawLine(const string name,
                                datetime t1, datetime t2,
                                double price, color clr,
                                ENUM_LINE_STYLE style, int width,
                                bool rayRight) const
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

void CSessionHighLow::DrawBackground(const string name,
                                      datetime t1, datetime t2,
                                      double hi, double lo,
                                      color clr) const
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

void CSessionHighLow::DrawChartText(const string name,
                                     datetime t, double price,
                                     const string text, color clr,
                                     ENUM_ANCHOR_POINT anchor) const
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);

   ObjectSetInteger(0, name, OBJPROP_TIME,       t);
   ObjectSetDouble (0, name, OBJPROP_PRICE,      price);
   ObjectSetString (0, name, OBJPROP_TEXT,       text);
   ObjectSetString (0, name, OBJPROP_FONT,       m_s.labelFont);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   m_s.labelSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,     anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED,   false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
  }

bool CSessionHighLow::IsPanelRowEnabled(const int row) const
  {
   if(!m_panelInitialized)
     {
      if(row == SHL_PANEL_LINES || row == SHL_PANEL_LABELS)
         return true;
      if(row == SHL_PANEL_BACKGROUND)
         return false;
      if(row == SHL_PANEL_DAILY)
         return m_s.showDaily;
      return false;
     }

   return m_panel.RowEnabled(row);
  }

bool CSessionHighLow::ShowSessionBackgrounds() const
  {
   if(!m_panelInitialized)
      return false;

   return IsPanelRowEnabled(SHL_PANEL_BACKGROUND);
  }

bool CSessionHighLow::ShowTimeframeBackground() const
  {
   if(!m_s.tfBgEnabled)
      return false;

   if(!m_panelInitialized)
      return true;

   return IsPanelRowEnabled(SHL_PANEL_BACKGROUND);
  }

void CSessionHighLow::ApplyChartBackgroundColor() const
  {
   if(ShowTimeframeBackground())
     {
      ChartSetInteger(0, CHART_COLOR_BACKGROUND, m_s.chartBgColor);
      ChartSetInteger(0, CHART_SHOW_GRID, false);
      return;
     }

   if(ObjectFind(0, m_tfbOrigBg) >= 0)
     {
      color orig = (color)ObjectGetInteger(0, m_tfbOrigBg, OBJPROP_COLOR);
      ChartSetInteger(0, CHART_COLOR_BACKGROUND, orig);
     }
  }

string CSessionHighLow::OccBase(int sid, datetime startTime) const
  {
   return m_drawPrefix + IntegerToString(sid) + "_" + IntegerToString((long)startTime);
  }

string CSessionHighLow::FmtPrice(double price) const
  {
   return DoubleToString(price, _Digits);
  }

string CSessionHighLow::PanelPersistKey() const
  {
   return m_s.objPrefix + IntegerToString((long)ChartID()) + "_PANEL";
  }

string CSessionHighLow::PanelStateKey(const int row) const
  {
   return PanelPersistKey() + "_R" + IntegerToString(row);
  }

bool CSessionHighLow::HasPersistedPanelStates() const
  {
   if(!m_s.persistCheckedRows)
      return false;

   for(int row = 0; row < SHL_PANEL_ROW_COUNT; row++)
      if(GlobalVariableCheck(PanelStateKey(row)))
         return true;

   return false;
  }

int CSessionHighLow::ResolvePanelX() const
  {
   int width  = MathMax(150, m_s.panelWidth);
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);

   if(m_s.panelCorner == CORNER_RIGHT_UPPER || m_s.panelCorner == CORNER_RIGHT_LOWER)
      return MathMax(0, chartW - width - m_s.panelX);

   return MathMax(0, m_s.panelX);
  }

int CSessionHighLow::ResolvePanelY() const
  {
   int height = MathMax(18, m_s.panelToggleHeight) +
                SHL_PANEL_ROW_COUNT * MathMax(18, m_s.panelRowHeight) +
                MathMax(0, m_s.panelPadH);
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);

   if(m_s.panelCorner == CORNER_LEFT_LOWER || m_s.panelCorner == CORNER_RIGHT_LOWER)
      return MathMax(0, chartH - height - m_s.panelY);

   return MathMax(0, m_s.panelY);
  }

STogglePanelConfig CSessionHighLow::BuildPanelConfig() const
  {
   STogglePanelConfig cfg;
   cfg.x                  = ResolvePanelX();
   cfg.y                  = ResolvePanelY();
   cfg.width              = MathMax(150, m_s.panelWidth);
   cfg.toggleHeight       = MathMax(18, m_s.panelToggleHeight);
   cfg.rowHeight          = MathMax(18, m_s.panelRowHeight);
   cfg.checkboxSize       = MathMax(10, m_s.panelCheckboxSize);
   cfg.padX               = MathMax(2, m_s.panelPadX);
   cfg.padH               = MathMax(0, m_s.panelPadH);
   cfg.fontSize           = MathMax(8, m_s.panelFontSize);
   cfg.clrBg              = m_s.panelBgColor;
   cfg.clrAccent          = m_s.panelAccentColor;
   cfg.clrText            = m_s.panelTextColor;
   cfg.title              = (m_s.panelTitle == "" ? "Sessions" : m_s.panelTitle);
   cfg.fontButton         = "Arial Bold";
   cfg.fontLabel          = "Arial";
   cfg.persistPosition    = m_s.persistPanelPos;
   cfg.persistCheckedRows = m_s.persistCheckedRows;
   cfg.persistKey         = PanelPersistKey();
   return cfg;
  }

void CSessionHighLow::InitPanel()
  {
   m_panelInitialized = false;
   if(!m_s.showPanel)
      return;

   string labels[SHL_PANEL_ROW_COUNT] =
     {
      "Lines",
      "Labels",
      "Background",
      "Daily H/L"
     };

   STogglePanelConfig cfg = BuildPanelConfig();
   if(!m_panel.Init(m_panelPrefix, cfg, labels, SHL_PANEL_ROW_COUNT, true))
      return;

   m_panelInitialized = true;
   ApplyDefaultPanelState();
  }

void CSessionHighLow::ApplyDefaultPanelState()
  {
   if(!m_panelInitialized || HasPersistedPanelStates())
      return;

   m_panel.SetRowEnabled(SHL_PANEL_LINES, true);
   m_panel.SetRowEnabled(SHL_PANEL_LABELS, true);
   m_panel.SetRowEnabled(SHL_PANEL_BACKGROUND, false);
   m_panel.SetRowEnabled(SHL_PANEL_DAILY, m_s.showDaily);
  }

//=============================================================================
//   High-level drawing
//=============================================================================

void CSessionHighLow::DrawOccurrence(int sid,
                                      const SSessionConfig    &cfg,
                                      const SSessionOccurrence &occ,
                                      int idxBack) const
  {
   string base      = OccBase(sid, occ.timeStart);
   bool   rayRight  = occ.isOpen && m_s.extendCurrent;
   bool   showLines = IsPanelRowEnabled(SHL_PANEL_LINES);
   bool   showLbls  = IsPanelRowEnabled(SHL_PANEL_LABELS);
   bool   showBg    = ShowSessionBackgrounds();

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

//--- Draw daily high/low lines + labels for the last lookback broker days.
//    Uses PERIOD_D1 directly — one authoritative bar per calendar day.
void CSessionHighLow::DrawDailyHL() const
  {
   if(!IsPanelRowEnabled(SHL_PANEL_DAILY))
      return;

   //--- Fetch one extra bar so each past day has a known end time (= next day open)
   int count = m_s.lookback + 1;

   datetime times[];
   double   highs[], lows[];
   ArraySetAsSeries(times, false);
   ArraySetAsSeries(highs, false);
   ArraySetAsSeries(lows,  false);

   if(CopyTime(_Symbol, PERIOD_D1, 0, count, times) <= 0) return;
   if(CopyHigh(_Symbol, PERIOD_D1, 0, count, highs) <= 0) return;
   if(CopyLow (_Symbol, PERIOD_D1, 0, count, lows)  <= 0) return;

   int n             = ArraySize(times);
   int firstDrawable = (n == count) ? 1 : 0;   // skip oldest — used only for end-time

   for(int i = firstDrawable; i < n; i++)
     {
      bool     isToday  = (i == n - 1);
      datetime dayStart = times[i];
      datetime dayEnd   = isToday ? (datetime)iTime(_Symbol, _Period, 0) : times[i + 1];
      bool     rayRight = isToday && m_s.extendCurrent;
      string   base     = m_drawPrefix + "D_" + IntegerToString((long)dayStart);
      int      idxBack  = (n - 1) - i;
      string   tag      = idxBack > 0 ? " #" + IntegerToString(idxBack) + " " : " ";

      ENUM_LINE_STYLE ls = isToday ? STYLE_SOLID : m_s.dailyStyle;
      DrawLine(base + "_H", dayStart, dayEnd, highs[i], m_s.dailyHighColor, ls, m_s.dailyWidth, rayRight);
      DrawLine(base + "_L", dayStart, dayEnd, lows[i],  m_s.dailyLowColor,  ls, m_s.dailyWidth, rayRight);

      datetime lblTime = dayStart + (datetime)((long)(dayEnd - dayStart) / 2);
      DrawChartText(base + "_LH", lblTime, highs[i], "Day" + tag + FmtPrice(highs[i]), m_s.dailyHighColor, ANCHOR_LOWER);
      DrawChartText(base + "_LL", lblTime, lows[i],  "Day" + tag + FmtPrice(lows[i]),  m_s.dailyLowColor,  ANCHOR_UPPER);
     }
  }

//=============================================================================
//   Timeframe background
//=============================================================================

//--- Save the chart's original bg color (once per indicator lifetime) and apply
//    InpChartBgColor.  Uses a persistent chart object so the original survives
//    parameter-change re-inits (OnDeinit + OnInit cycles).
void CSessionHighLow::InitTFBackground()
  {
   if(ObjectFind(0, m_tfbOrigBg) < 0)
     {
      color orig = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
      ObjectCreate(0, m_tfbOrigBg, OBJ_TEXT, 0, 0, 0);
      ObjectSetInteger(0, m_tfbOrigBg, OBJPROP_COLOR,  orig);
      ObjectSetInteger(0, m_tfbOrigBg, OBJPROP_HIDDEN, true);
     }

   ApplyChartBackgroundColor();
  }

//--- Draw higher-TF candle shapes as filled rectangles (upper wick / body / lower wick).
//    Only active when chart timeframe is strictly lower than tfBgTimeframe.
void CSessionHighLow::DrawTimeframeBg() const
  {
   ApplyChartBackgroundColor();

   if(!ShowTimeframeBackground())
      return;
   if(PeriodSeconds(_Period) >= PeriodSeconds(m_s.tfBgTimeframe))
      return;

   int count = m_s.tfBgLookback + 1;   // +1: oldest bar supplies t2 for the next

   datetime times[];
   double   opens[], highs[], lows[], closes[];
   ArraySetAsSeries(times,  false);
   ArraySetAsSeries(opens,  false);
   ArraySetAsSeries(highs,  false);
   ArraySetAsSeries(lows,   false);
   ArraySetAsSeries(closes, false);

   if(CopyTime (_Symbol, m_s.tfBgTimeframe, 0, count, times)  <= 0) return;
   if(CopyOpen (_Symbol, m_s.tfBgTimeframe, 0, count, opens)  <= 0) return;
   if(CopyHigh (_Symbol, m_s.tfBgTimeframe, 0, count, highs)  <= 0) return;
   if(CopyLow  (_Symbol, m_s.tfBgTimeframe, 0, count, lows)   <= 0) return;
   if(CopyClose(_Symbol, m_s.tfBgTimeframe, 0, count, closes) <= 0) return;

   int n             = ArraySize(times);
   int firstDrawable = (n == count) ? 1 : 0;

   for(int i = firstDrawable; i < n; i++)
     {
      bool     isCurrent = (i == n - 1);
      datetime t1        = times[i];
      datetime t2        = isCurrent ? (datetime)iTime(_Symbol, _Period, 0) : times[i + 1];
      double   bodyHi    = MathMax(opens[i], closes[i]);
      double   bodyLo    = MathMin(opens[i], closes[i]);
      string   base      = m_drawPrefix + "TFB_" + IntegerToString((long)t1);

      //--- Three non-overlapping rectangles; wick zones never overlap body zone
      if(highs[i] > bodyHi)
         DrawBackground(base + "_UW", t1, t2, highs[i], bodyHi, m_s.tfWickColor);

      DrawBackground(base + "_BD", t1, t2, bodyHi, bodyLo, m_s.tfBodyColor);

      if(bodyLo > lows[i])
         DrawBackground(base + "_LW", t1, t2, bodyLo, lows[i], m_s.tfWickColor);
     }
  }

#endif // __FXTT_CSESSIONHIGHLOW_MQH__