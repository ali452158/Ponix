//+------------------------------------------------------------------+
//|                                               Ponix.mq5 |
//|        إكسبيرت مخصص لمؤشر PainX فقط - بيع فقط (صيد الهبطة)      |
//|                                                                  |
//|  المواصفات (حسب الطلب):                                          |
//|   - يعمل على PainX فقط (يرفض أي رمز آخر)                        |
//|   - بيع أساسي إجباري + شراء بعد البيع (3.07) يخرج بعد 10 شمعات دقيقة                                     |
//|   - لوت ثابت 0.1 (الحد الأدنى للمنصة)                                               |
//|   - خسارة قصوى 3 دولار (ستوب دولاري)                            |
//|   - هدف ربح 10 دولارات (خمسة أضعاف الخسارة)                      |
//|   - لا خروج زمني: الصفقة تنتهي بالستوب أو الهدف فقط             |
//|   - جديد 3.07: شراء بعد البيع - بعد إغلاق أي صفقة بيع يفتح شراء لالتقاط الارتداد: خروج بعد 10 شمعات فريم الدقيقة، ستوب 3$، حماية أرباح تعمل على الشراء
//|   - جديد 3.06: إلغاء كل آليات التوقف بأمر المستخدم - بلا فاصل بين الصفقات، بلا حد صفقات يومي، بلا انتظار بعد الخسارة، بلا حد خسارة يومي - البوت يعمل دائماً مهما كانت الخسارة
//|   - 3.05: إلغاء التوقف اليومي | 3.04: ستوب متحرك 75% | 3.03: حجز 50% | 3.02: عتبة سبايك تلقائية + قفل الاستحقاق | 3.01: لوت 0.1 + قفل تعادل + تتبع أرباح     |
//|                                                                  |
//|  ⚠ تحذير: المؤشرات الاصطناعية عالية المخاطر. جرّب على حساب       |
//|     تجريبي أولاً ولا تخاطر بمال لا تتحمل خسارته.                 |
//+------------------------------------------------------------------+
#property copyright "PainX Sell EA"
#property version   "3.07"
#property description "PainX: بيع أساسي + شراء بعد البيع | صيد الانهيار الحي | خسارة 3$ | هدف 10$ | حماية أرباح"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| نمط الدخول                                                       |
//+------------------------------------------------------------------+
enum ENUM_CRASH_MODE
  {
   ENTRY_CRASH_RIDE = 0,   // صيد الانهيار الحي: يدخل أثناء الهبوط الفعلي (موصى به)
   ENTRY_DUE_WINDOW = 1    // نافذة الاستحقاق: يدخل قبل موعد الانهيار (القديم)
  };

//+------------------------------------------------------------------+
//| المدخلات                                                         |
//+------------------------------------------------------------------+
input group "====== الإعدادات العامة ======"
input long   InpMagic             = 990012;   // الماجيك نمبر
input int    InpSlippagePoints    = 100;      // أقصى انزلاق (نقاط)
input int    InpMaxSpreadPoints   = 0;        // أقصى سبريد (0 = معطل)
input int    InpMaxPositions      = 1;        // أقصى صفقات مفتوحة
input int    InpMinSecondsBetween = 0;        // ثواني بين صفقة وأخرى (0 = بلا فاصل - ألغيها المستخدم)
input int    InpMaxTradesPerDay   = 0;       // أقصى صفقات يومياً (0 = بلا حد - ألغيها المستخدم)
input int    InpLossCooldownMin   = 0;       // انتظار بعد صفقة خاسرة (0 = معطل - البوت لا يتوقف حتى لو خسر)
input bool   InpShowPanel         = true;     // إظهار لوحة المعلومات

input group "====== المخاطر (بالدولار) ======"
input double InpFixedLot          = 0.1;      // اللوت الثابت (حد المنصة الأدنى 0.1)
input double InpStopLossUSD       = 3.0;      // خسارة قصوى بالدولار
input double InpTakeProfitUSD     = 10.0;     // هدف الربح بالدولار (خمسة أضعاف الخسارة)
input double InpMaxDailyLossPct   = 0.0;      // إيقاف يومي عند خسارة % (0 = معطل: البوت لا يتوقف أبداً)

input group "====== توقيت الدخول (عداد السبايك) ======"
input int    InpSpikeMinPoints    = 0;        // أقل حجم سبايك هابط بالنقاط (0 = تلقائي من التاريخ)
input int    InpAvgIntervalManual = 600;      // متوسط الفاصل اليدوي (لو فشل الاستخراج من الاسم)
input double InpDueStart          = 1.05;     // بداية نافذة الدخول (× المتوسط)
input double InpDueEnd            = 1.60;     // نهاية نافذة الدخول (× المتوسط)
input int    InpInitTicksHistory  = 80000;    // تيكات التاريخ لتهيئة العداد

input group "====== نمط الدخول (جديد 3.00) ======"
input ENUM_CRASH_MODE InpEntryMode  = ENTRY_CRASH_RIDE; // نمط الدخول
input int    InpCrashLookback       = 20;       // تيكات كشف الانهيار الحي
input double InpCrashMult           = 10.0;     // قوة الانهيار (× متوسط حركة التيك)
input bool   InpRequireOverdue      = true;     // اشتراط تأخر الانهيار عن دورته
input double InpOverdueMin          = 0.80;     // أدنى تأخر (× المتوسط)

input group "====== الشراء بعد البيع (جديد 3.07) ======"
input bool   InpUseBuyAfterSell   = true;     // تفعيل الشراء بعد إغلاق البيع
input int    InpBuyCandlesM1      = 10;       // خروج الشراء بعد كم شمعة فريم الدقيقة
input double InpBuyStopUSD        = 3.0;      // ستوب الشراء بالدولار
input double InpBuyTakeProfitUSD  = 0.0;      // هدف الشراء بالدولار (0 = معطل - الخروج بالشمعات)

input group "====== حماية الأرباح (جديد 3.00) ======"
input bool   InpUseBreakEven        = true;     // قفل التعادل
input double InpBETriggerUSD        = 2.0;      // تفعيل القفل عند ربح (دولار)
input int    InpBEBufferPoints      = 30;       // ربح مؤمن عند القفل (نقاط)
input bool   InpUseTrailing         = true;     // ستوب متحرك يحمي الأرباح
input double InpLockStartUSD        = 1.0;      // بدء الحجز عند ربح (دولار)
input double InpLockPct             = 75.0;     // نسبة الحجز من الربح % (75 = كل دولار يحجز 75 سنت لحظياً)
input double InpTrailStepUSD        = 0.05;     // أدنى تحسين لتحديث الستوب (0.05 = لحظي أول بأول)

//+------------------------------------------------------------------+
//| المتغيرات العامة                                                 |
//+------------------------------------------------------------------+
CTrade   g_trade;
int      g_avgInterval   = 600;
long     g_ticksSince    = 1000000;   // تيكات منذ آخر سبايك هابط
double   g_prevPrice     = 0.0;
datetime g_lastSpikeTime = 0;
datetime g_lastTradeTime = 0;
datetime g_lastPanelTime = 0;
datetime g_lastCloseTime   = 0;      // وقت إغلاق آخر صفقة
double   g_lastCloseProfit = 0.0;    // نتيجة آخر صفقة مغلقة (لانتظار ما بعد الخسارة)
bool     g_buyPending      = false;  // (3.07) جاهز لفتح شراء بعد إغلاق صفقة بيع
datetime g_buyEntryBar     = 0;      // (3.07) وقت شمعة الدقيقة عند فتح الشراء
double   g_buySlPoints     = 0.0;    // (3.07) مسافة ستوب الشراء بالنقاط
double   g_buyTpPoints     = 0.0;    // (3.07) مسافة هدف الشراء بالنقاط (0 = معطل)

int      g_curDay        = -1;
double   g_dayBalance    = 0.0;
bool     g_halted        = false;
int      g_tradesToday   = 0;

double   g_lot           = 0.1;       // اللوت الفعلي بعد التحقق من حدود الرمز
double   g_pointValuePos = 0.0;       // قيمة النقطة بالدولار لهذا اللوت
double   g_slPoints      = 0.0;       // مسافة الستوب بالنقاط (من ستوب الدولار)
double   g_tpPoints      = 0.0;       // مسافة الهدف بالنقاط (من هدف الدولار)
double   g_avgTickPts    = 0.0;       // متوسط حركة التيك (نقاط)
double   g_spikeAutoPts  = 0.0;       // عتبة السبايك التلقائية (نقاط) - مشتقة من التاريخ
bool     g_crashOverdue  = false;     // هل كان الانهيار مستحقاً عند بدايته؟ (قفل لحظة البدء)
double   g_recentPrices[64];          // حلقة آخر تيكات لكشف الانهيار الحي
int      g_recentCnt    = 0;          // عدد الأسعار المخزنة حالياً

//+------------------------------------------------------------------+
//| استخراج متوسط الفاصل من اسم الرمز (مثال: "PainX 999" -> 999)    |
//+------------------------------------------------------------------+
long ParseIntervalFromName(const string sname)
  {
   string s = sname;
   StringToLower(s);
   int    len  = StringLen(s);
   long   best = -1;
   string num  = "";
   for(int i = 0; i < len; i++)
     {
      string c = StringSubstr(s, i, 1);
      if(c >= "0" && c <= "9")
         num += c;
      else
        {
         if(StringLen(num) > 0)
           {
            long v = StringToInteger(num);
            if(v >= 100 && v <= 100000 && v > best)
               best = v;
           }
         num = "";
        }
     }
   if(StringLen(num) > 0)
     {
      long v = StringToInteger(num);
      if(v >= 100 && v <= 100000 && v > best)
         best = v;
     }
   return best;
  }

//+------------------------------------------------------------------+
//| اختيار نمط التعبئة المناسب للرمز                                 |
//+------------------------------------------------------------------+
void SetFillingMode()
  {
   long fm = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fm & SYMBOL_FILLING_FOK) != 0)
      g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((fm & SYMBOL_FILLING_IOC) != 0)
      g_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      g_trade.SetTypeFilling(ORDER_FILLING_RETURN);
  }

//+------------------------------------------------------------------+
//| هل الدلتا تمثل سبايك هابط (مؤشر PainX ينخفض ثم ينهار)؟           |
//+------------------------------------------------------------------+
bool IsSpikeDelta(const double delta)
  {
   if(delta >= 0.0)
      return false;
   double thPts = (double)InpSpikeMinPoints;
   if(thPts <= 0.0)
      thPts = (g_spikeAutoPts > 0.0) ? g_spikeAutoPts : 30.0;
   return (MathAbs(delta) >= thPts * _Point);
  }

//+------------------------------------------------------------------+
//| تهيئة عداد السبايك من تيكات التاريخ                              |
//+------------------------------------------------------------------+
void InitFromHistory()
  {
   MqlTick arr[];
   int n = CopyTicks(_Symbol, arr, COPY_TICKS_ALL, 0, (uint)MathMax(InpInitTicksHistory, 1000));
   if(n <= 0)
     {
      Print("PainX EA: تعذر جلب تيكات التاريخ، سيبدأ العداد من الصفر.");
      return;
     }
   // المرحلة 1: متوسط حركة التيك + جمع التيكات الهابطة لاشتقاق عتبة السبايك تلقائياً
   double prev   = 0.0;
   double sumAbs = 0.0;
   long   cnt    = 0;
   double neg[];
   int    negCnt = 0;
   ArrayResize(neg, n);
   for(int i = 0; i < n; i++)
     {
      double p = arr[i].bid;
      if(prev > 0.0)
        {
         double d = p - prev;
         sumAbs += MathAbs(d);
         cnt++;
         if(d < 0.0)
           {
            neg[negCnt] = d;
            negCnt++;
           }
        }
      prev = p;
     }
   if(cnt > 0)
      g_avgTickPts = (sumAbs / (double)cnt) / _Point;

   // العتبة التلقائية: أصغر تيك بين أعلى 0.5% من التيكات الهابطة (تيكات الانهيارات الحقيقية)
   if(negCnt >= 200)
     {
      ArrayResize(neg, negCnt);
      ArraySort(neg);
      int k = (int)MathFloor(negCnt * 0.005);
      if(k < 1)
         k = 1;
      double cand     = MathAbs(neg[k - 1]) / _Point;
      double floorPts = 20.0;
      if(g_avgTickPts > 0.0)
         floorPts = MathMax(floorPts, 2.0 * g_avgTickPts);
      g_spikeAutoPts = MathMax(cand, floorPts);
     }

   // المرحلة 2: بناء العداد بعتبة السبايك المشتقة + تسجيل حالة الاستحقاق عند كل انهيار
   prev        = 0.0;
   long  since = 0;
   for(int i = 0; i < n; i++)
     {
      double p = arr[i].bid;
      if(prev > 0.0)
        {
         if(IsSpikeDelta(p - prev))
           {
            g_crashOverdue  = (since >= (long)(g_avgInterval * InpOverdueMin));
            since           = 0;
            g_lastSpikeTime = arr[i].time;
           }
         else
            since++;
        }
      prev = p;
     }
   g_prevPrice  = prev;
   g_ticksSince = since;
   PrintFormat("PainX EA: تهيئة العداد من %d تيك | متوسط حركة التيك=%.1f نقطة | عتبة السبايك=%.0f نقطة | تيكات منذ آخر سبايك=%I64d",
               n, g_avgTickPts, g_spikeAutoPts, g_ticksSince);
  }

//+------------------------------------------------------------------+
//| نافذة الاستحقاق: المؤشر قارب على انهياره الهابط                   |
//+------------------------------------------------------------------+
bool InDueWindow()
  {
   long start = (long)(g_avgInterval * InpDueStart);
   long end   = (long)(g_avgInterval * InpDueEnd);
   return (g_ticksSince >= start && g_ticksSince <= end);
  }

//+------------------------------------------------------------------+
//| تخزين آخر تيكات لكشف الانهيار الحي                               |
//+------------------------------------------------------------------+
void PushRecentPrice(const double price)
  {
   int cap = InpCrashLookback + 1;
   if(cap > 64) cap = 64;
   if(cap < 2)  cap = 2;
   if(g_recentCnt < cap)
     {
      g_recentPrices[g_recentCnt] = price;
      g_recentCnt++;
     }
   else
     {
      for(int i = 1; i < cap; i++)
         g_recentPrices[i - 1] = g_recentPrices[i];
      g_recentPrices[cap - 1] = price;
     }
  }

//+------------------------------------------------------------------+
//| كشف الانهيار الحي: هل السعر أنهار فعلياً خلال آخر تيكات؟          |
//+------------------------------------------------------------------+
bool CrashActive()
  {
   int cap = InpCrashLookback + 1;
   if(cap > 64) cap = 64;
   if(cap < 2)  cap = 2;
   if(g_recentCnt < cap)
      return false;
   double thPts = (g_avgTickPts > 0.0) ? InpCrashMult * g_avgTickPts : 50.0;
   double delta = g_recentPrices[cap - 1] - g_recentPrices[0];
   return (delta <= -thPts * _Point);
  }

//+------------------------------------------------------------------+
//| اشتراط تأخر الانهيار عن دورته (يقلل الدخول على هبوطات كاذبة)     |
//+------------------------------------------------------------------+
bool OverdueEnough()
  {
   if(!InpRequireOverdue)
      return true;
   // أثناء الانهيار الحي: نستخدم حالة "مستحق" المسجلة لحظة بداية الانهيار
   // (لأن بداية الانهيار نفسها تصفّر العداد - إصلاح 3.02)
   if(CrashActive())
      return g_crashOverdue;
   return (g_ticksSince >= (long)(g_avgInterval * InpOverdueMin));
  }

//+------------------------------------------------------------------+
//| إشارة الدخول حسب النمط المختار                                   |
//+------------------------------------------------------------------+
bool EntrySignal()
  {
   if(InpEntryMode == ENTRY_CRASH_RIDE)
      return (CrashActive() && OverdueEnough());
   return InDueWindow();
  }

//+------------------------------------------------------------------+
//| فلاتر مساعدة                                                     |
//+------------------------------------------------------------------+
bool SpreadOK()
  {
   if(InpMaxSpreadPoints <= 0)
      return true;
   long sp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (sp <= InpMaxSpreadPoints);
  }

bool TerminalAllowed()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return false;
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//| فترة انتظار إضافية بعد صفقة خاسرة (فترات طويلة)                  |
//+------------------------------------------------------------------+
bool LossCooldownOK()
  {
   if(InpLossCooldownMin <= 0)
      return true;
   if(g_lastCloseTime == 0 || g_lastCloseProfit >= 0.0)
      return true;
   return ((TimeCurrent() - g_lastCloseTime) >= (long)InpLossCooldownMin * 60);
  }

//+------------------------------------------------------------------+
//| الحماية اليومية: حد الخسارة وعدّاد الصفقات                       |
//+------------------------------------------------------------------+
void UpdateDailyGuard()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_year != g_curDay)
     {
      g_curDay      = dt.day_of_year;
      g_dayBalance  = AccountInfoDouble(ACCOUNT_BALANCE);
      g_halted      = false;
      g_tradesToday = 0;
     }
   if(!g_halted && InpMaxDailyLossPct > 0.0 && g_dayBalance > 0.0)
     {
      double pl = AccountInfoDouble(ACCOUNT_BALANCE) - g_dayBalance;
      if(pl <= -(g_dayBalance * InpMaxDailyLossPct / 100.0))
        {
         g_halted = true;
         Print("PainX EA: توقف يومي - تم الوصول إلى حد الخسارة اليومية.");
        }
     }
  }

//+------------------------------------------------------------------+
//| عدّ صفقات هذا الإكسبيرت                                          |
//+------------------------------------------------------------------+
int CountMyPositions(int &buyCnt, int &sellCnt)
  {
   buyCnt  = 0;
   sellCnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         buyCnt++;
      else
         sellCnt++;
     }
   return (buyCnt + sellCnt);
  }

//+------------------------------------------------------------------+
//| تحديث عداد التيكات بعد كل تيك                                    |
//+------------------------------------------------------------------+
void UpdateTickState()
  {
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t))
      return;
   double price = t.bid;
   if(g_prevPrice > 0.0)
     {
      if(IsSpikeDelta(price - g_prevPrice))
        {
         g_crashOverdue  = (g_ticksSince >= (long)(g_avgInterval * InpOverdueMin));
         g_ticksSince    = 0;
         g_lastSpikeTime = t.time;
        }
      else
         g_ticksSince++;
     }
   g_prevPrice = price;
   PushRecentPrice(price);
  }

//+------------------------------------------------------------------+
//| إدارة الصفقات المفتوحة: ستوب وهدف بالدولار (المنفذان فعلياً)      |
//+------------------------------------------------------------------+
void ManagePositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      bool   isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double pl    = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      // استرجاع وقت شمعة دخول الشراء بعد إعادة تشغيل الإكسبيرت
      if(isBuy && g_buyEntryBar == 0)
        {
         int shift = iBarShift(_Symbol, PERIOD_M1, (datetime)PositionGetInteger(POSITION_TIME));
         if(shift >= 0)
            g_buyEntryBar = iTime(_Symbol, PERIOD_M1, shift);
        }

      // ستوب الدولار: إغلاق فوري عند بلوغ الخسارة القصوى (بيع 3$ / شراء 3$)
      double stopUSD = isBuy ? InpBuyStopUSD : InpStopLossUSD;
      if(stopUSD > 0.0 && pl <= -stopUSD)
        {
         PrintFormat("PainX EA: ستوب الدولار (%s) - إغلاق الصفقة #%I64u | الخسارة=%.2f", (isBuy ? "شراء" : "بيع"), tk, pl);
         g_trade.PositionClose(tk, (ulong)InpSlippagePoints);
         continue;
        }

      // هدف الدولار: إغلاق فوري عند بلوغ الربح المستهدف (الشراء: 0 = معطل)
      double tpUSD = isBuy ? InpBuyTakeProfitUSD : InpTakeProfitUSD;
      if(tpUSD > 0.0 && pl >= tpUSD)
        {
         PrintFormat("PainX EA: تحقق هدف الدولار (%s) - إغلاق الصفقة #%I64u | الربح=%.2f", (isBuy ? "شراء" : "بيع"), tk, pl);
         g_trade.PositionClose(tk, (ulong)InpSlippagePoints);
         continue;
        }

      // (3.07) خروج الشراء بعد عدد شمعات فريم الدقيقة
      if(isBuy && InpBuyCandlesM1 > 0 && g_buyEntryBar > 0)
        {
         datetime curBar = iTime(_Symbol, PERIOD_M1, 0);
         int barsElapsed = (int)((curBar - g_buyEntryBar) / 60);
         if(barsElapsed >= InpBuyCandlesM1)
           {
            PrintFormat("PainX EA: اكتملت %d شمعة دقيقة - إغلاق الشراء #%I64u | النتيجة=%.2f", InpBuyCandlesM1, tk, pl);
            g_trade.PositionClose(tk, (ulong)InpSlippagePoints);
            continue;
           }
        }

      // حماية الأرباح: قفل التعادل + التتبع (الجديد في 3.00)
      ProtectProfit(tk);
     }
  }

//+------------------------------------------------------------------+
//| حماية الأرباح: قفل تعادل + تتبع ستوب (للبيع والشراء)             |
//+------------------------------------------------------------------+
void ProtectProfit(const ulong ticket)
  {
   if(!InpUseBreakEven && !InpUseTrailing)
      return;
   if(!PositionSelectByTicket(ticket))
      return;

   double open  = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL = PositionGetDouble(POSITION_SL);
   double curTP = PositionGetDouble(POSITION_TP);
   double pl    = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   bool   isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t))
      return;
   double bid = t.bid;
   double ask = t.ask;

   long   stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist    = MathMax((double)stopsLevel, 1.0) * _Point;

   double newSL  = 0.0;
   bool   hasNew = false;

   if(isBuy)
     {
      // قفل التعادل للشراء: الستوب ينتقل فوق سعر الدخول (ربح مؤمن)
      if(InpUseBreakEven && pl >= InpBETriggerUSD)
        {
         double beSL = NormalizeDouble(open + InpBEBufferPoints * _Point, _Digits);
         if((bid - beSL) >= minDist && (curSL == 0.0 || beSL > curSL))
           {
            newSL  = beSL;
            hasNew = true;
           }
        }

      // الستوب المتحرك للشراء (3.07): يحجز 75% من الربح - الستوب يصعد مع السعر ولا يتراجع أبداً
      if(InpUseTrailing && pl >= InpLockStartUSD)
        {
         double lockUSD = pl * InpLockPct / 100.0;
         double lockPts = (g_pointValuePos > 0.0) ? (lockUSD / g_pointValuePos) : 0.0;
         if(lockPts > 0.0)
           {
            double trailSL = NormalizeDouble(open + lockPts * _Point, _Digits);
            if((bid - trailSL) >= minDist && (curSL == 0.0 || trailSL > curSL))
              {
               double stepPts = (g_pointValuePos > 0.0) ? (InpTrailStepUSD / g_pointValuePos) : 0.0;
               if(curSL == 0.0 || (trailSL - curSL) >= stepPts * _Point)
                 {
                  if(!hasNew || trailSL > newSL)
                    {
                     newSL  = trailSL;
                     hasNew = true;
                    }
                 }
              }
           }
        }
     }
   else
     {
      // قفل التعادل: عند الربح المحدد، انقل الستوب تحت سعر الدخول (ربح مؤمن)
      if(InpUseBreakEven && pl >= InpBETriggerUSD)
        {
         double beSL = NormalizeDouble(open - InpBEBufferPoints * _Point, _Digits);
         if((beSL - ask) >= minDist && (curSL == 0.0 || beSL < curSL))
           {
            newSL  = beSL;
            hasNew = true;
           }
        }

      // الستوب المتحرك (3.04): يحجز 75% من الربح لحظياً - كل دولار ربح يثبت 75 سنت منه
      // يُحسب من الربح الحالي لكن الستوب لا يتراجع أبداً - فيقفل عملياً 75% من أعلى ربح بلغته الصفقة
      if(InpUseTrailing && pl >= InpLockStartUSD)
        {
         double lockUSD = pl * InpLockPct / 100.0;
         double lockPts = (g_pointValuePos > 0.0) ? (lockUSD / g_pointValuePos) : 0.0;
         if(lockPts > 0.0)
           {
            double trailSL = NormalizeDouble(open - lockPts * _Point, _Digits);
            if((trailSL - ask) >= minDist && (curSL == 0.0 || trailSL < curSL))
              {
               double stepPts = (g_pointValuePos > 0.0) ? (InpTrailStepUSD / g_pointValuePos) : 0.0;
               if(curSL == 0.0 || (curSL - trailSL) >= stepPts * _Point)
                 {
                  if(!hasNew || trailSL < newSL)
                    {
                     newSL  = trailSL;
                     hasNew = true;
                    }
                 }
              }
           }
        }
     }

   if(hasNew && MathAbs(newSL - curSL) > _Point / 2.0)
     {
      if(g_trade.PositionModify(ticket, newSL, curTP))
         PrintFormat("PainX EA: حماية أرباح - ستوب جديد عند %s | الربح العائم=%.2f$", DoubleToString(newSL, _Digits), pl);
      else
         PrintFormat("PainX EA: فشل تعديل ستوب الحماية | retcode=%u", g_trade.ResultRetcode());
     }
  }

//+------------------------------------------------------------------+
//| فتح صفقة بيع (الاتجاه الأساسي - صيد الانهيار)                    |
//+------------------------------------------------------------------+
bool OpenSell()
  {
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t))
      return false;
   double price = t.bid;

   double sl = 0.0, tp = 0.0;
   if(g_slPoints > 0.0)
      sl = price + g_slPoints * _Point;
   if(g_tpPoints > 0.0)
      tp = price - g_tpPoints * _Point;

   long   stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist    = MathMax((double)stopsLevel, 1.0) * _Point;
   if(sl > 0.0 && (sl - price) < minDist)
      sl = price + minDist;
   if(tp > 0.0 && (price - tp) < minDist)
      tp = price - minDist;
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   bool ok = g_trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, g_lot, price, sl, tp, "PainX_EA");
   if(ok && g_trade.ResultRetcode() == TRADE_RETCODE_DONE)
     {
      g_lastTradeTime = TimeCurrent();
      g_tradesToday++;
      PrintFormat("PainX EA: فتح بيع | لوت=%.2f | ستوب=%.0f نقطة (%.2f$) | هدف=%.0f نقطة (%.2f$) | تيكات منذ سبايك=%I64d",
                  g_lot, g_slPoints, InpStopLossUSD, g_tpPoints, InpTakeProfitUSD, g_ticksSince);
      return true;
     }
   PrintFormat("PainX EA: فشل فتح الصفقة | retcode=%u | %s",
               g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
   return false;
  }

//+------------------------------------------------------------------+
//| فتح صفقة شراء بعد إغلاق البيع (جديد 3.07) - لالتقاط الارتداد     |
//+------------------------------------------------------------------+
bool OpenBuy()
  {
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t))
      return false;
   double price = t.ask;

   double sl = 0.0, tp = 0.0;
   if(g_buySlPoints > 0.0)
      sl = price - g_buySlPoints * _Point;
   if(g_buyTpPoints > 0.0)
      tp = price + g_buyTpPoints * _Point;

   long   stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist    = MathMax((double)stopsLevel, 1.0) * _Point;
   if(sl > 0.0 && (price - sl) < minDist)
      sl = price - minDist;
   if(tp > 0.0 && (tp - price) < minDist)
      tp = price + minDist;
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   bool ok = g_trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, g_lot, price, sl, tp, "PainX_BuyAfterSell");
   if(ok && g_trade.ResultRetcode() == TRADE_RETCODE_DONE)
     {
      g_buyPending    = false;
      g_buyEntryBar   = iTime(_Symbol, PERIOD_M1, 0);
      g_lastTradeTime = TimeCurrent();
      g_tradesToday++;
      PrintFormat("PainX EA: فتح شراء بعد البيع | لوت=%.2f | ستوب=%.0f نقطة (%.2f$) | الخروج بعد %d شمعة دقيقة",
                  g_lot, g_buySlPoints, InpBuyStopUSD, InpBuyCandlesM1);
      return true;
     }
   PrintFormat("PainX EA: فشل فتح الشراء | retcode=%u | %s",
               g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
   return false;
  }

//+------------------------------------------------------------------+
//| منطق الدخول: بيع داخل نافذة استحقاق الانهيار فقط                 |
//+------------------------------------------------------------------+
void TryEnter()
  {
   if(g_halted || !TerminalAllowed() || !SpreadOK())
      return;

   int buyCnt = 0, sellCnt = 0;
   if(CountMyPositions(buyCnt, sellCnt) >= InpMaxPositions)
      return;

   // (3.07) الشراء بعد البيع: أولوية فورية بعد إغلاق أي صفقة بيع
   if(g_buyPending)
     {
      OpenBuy();
      return;
     }

   if(InpMaxTradesPerDay > 0 && g_tradesToday >= InpMaxTradesPerDay)
      return;
   if(InpMinSecondsBetween > 0 && g_lastTradeTime > 0 && (TimeCurrent() - g_lastTradeTime) < InpMinSecondsBetween)
      return;
   if(!LossCooldownOK())
      return;
   if(sellCnt > 0)
      return;

   if(!EntrySignal())
      return;

   OpenSell();
  }

//+------------------------------------------------------------------+
//| سبب عدم الدخول الآن (للعرض في اللوحة)                             |
//+------------------------------------------------------------------+
string EntryBlockReason()
  {
   if(!TerminalAllowed())
      return "التداول الآلي مقفل - فعّل زر AutoTrading";
   if(g_halted)
      return "موقوف اليوم: حد الخسارة اليومي";
   if(InpMaxTradesPerDay > 0 && g_tradesToday >= InpMaxTradesPerDay)
      return "اكتمل حد صفقات اليوم";
   if(g_lastTradeTime > 0)
     {
      long rem = (long)InpMinSecondsBetween - (long)(TimeCurrent() - g_lastTradeTime);
      if(rem > 0)
         return "فاصل بين الصفقات: باقي " + IntegerToString((int)MathCeil(rem / 60.0)) + " دقيقة";
     }
   if(!LossCooldownOK())
     {
      long rem2 = (long)InpLossCooldownMin * 60 - (long)(TimeCurrent() - g_lastCloseTime);
      if(rem2 > 0)
         return "انتظار بعد خسارة: باقي " + IntegerToString((int)MathCeil(rem2 / 60.0)) + " دقيقة";
     }
   int b = 0, s = 0;
   if(CountMyPositions(b, s) >= InpMaxPositions)
      return (b > 0) ? "صفقة شراء مفتوحة - تخرج بعد شمعات الدقيقة أو التتبع" : "يوجد صفقة بيع مفتوحة الآن";
   if(g_buyPending)
      return "بانتظار فتح الشراء بعد إغلاق البيع";
   if(InpEntryMode == ENTRY_CRASH_RIDE)
     {
      if(!CrashActive())
         return "بانتظار انهيار حي (لا هبوط عنيف الآن)";
      if(!OverdueEnough())
         return "الانهيار مبكر - لم يكن مستحقاً عند بدايته";
      return "إشارة دخول نشطة!";
     }
   if(!InDueWindow())
     {
      if(g_ticksSince < (long)(g_avgInterval * InpDueStart))
         return "منطقة آمنة - سبايك حديث";
      return "خارج النافذة - بانتظار الاستحقاق";
     }
   return "إشارة دخول نشطة!";
  }

//+------------------------------------------------------------------+
//| لوحة المعلومات على الشارت                                        |
//+------------------------------------------------------------------+
void UpdatePanel()
  {
   datetime now = TimeCurrent();
   if(now == g_lastPanelTime)
      return;
   g_lastPanelTime = now;

   int buyCnt = 0, sellCnt = 0;
   CountMyPositions(buyCnt, sellCnt);

   long   start = (long)(g_avgInterval * InpDueStart);
   long   end   = (long)(g_avgInterval * InpDueEnd);
   string state = "خارج النافذة";
   if(InDueWindow())
      state = "داخل نافذة الدخول";
   else if(g_ticksSince < start)
      state = "منطقة آمنة (سبايك حديث)";
   else
      state = "منطقة متأخرة (سبايك متأخر)";

   string s = "";
   s += "===== PainX EA v3.07 (صيد الانهيار + شراء الارتداد) =====\n";
   s += "الرمز: " + _Symbol + " | بيع أساسي + شراء بعد البيع\n";
   s += "-----------------------------------------\n";
   s += "اللوت: " + DoubleToString(g_lot, 2) + "\n";
   s += "الخسارة القصوى: " + DoubleToString(InpStopLossUSD, 2) + "$ (ستوب عند " + DoubleToString(g_slPoints, 0) + " نقطة)\n";
   s += "هدف الربح: " + DoubleToString(InpTakeProfitUSD, 2) + "$ (هدف عند " + DoubleToString(g_tpPoints, 0) + " نقطة)\n";
   s += "الخروج الزمني: لا يوجد - الستوب/الهدف فقط\n";
   s += "-----------------------------------------\n";
   s += "متوسط فاصل السبايك: " + IntegerToString(g_avgInterval) + " تيك\n";
   s += "تيكات منذ آخر سبايك هابط: " + IntegerToString(g_ticksSince) + "\n";
   s += "نافذة الدخول: [" + IntegerToString(start) + " .. " + IntegerToString(end) + "] تيك\n";
   s += "الحالة: " + state + "\n";
   string modeStr = (InpEntryMode == ENTRY_CRASH_RIDE) ? "صيد الانهيار الحي" : "نافذة الاستحقاق";
   s += "نمط الدخول: " + modeStr + "\n";
   string prot = "";
   if(InpUseBreakEven)
      prot += "قفل تعادل عند +" + DoubleToString(InpBETriggerUSD, 1) + "$ ";
   if(InpUseTrailing)
      prot += "| ستوب متحرك: يحجز " + DoubleToString(InpLockPct, 0) + "% من الربح من +" + DoubleToString(InpLockStartUSD, 1) + "$";
   s += "حماية الأرباح: " + ((prot == "") ? "معطلة" : prot) + "\n";
   if(InpUseBuyAfterSell)
      s += "الشراء بعد البيع: مفعّل | خروج بعد " + IntegerToString(InpBuyCandlesM1) + " شمعة دقيقة | ستوب الشراء " + DoubleToString(InpBuyStopUSD, 1) + "$\n";
   else
      s += "الشراء بعد البيع: معطل\n";
   if(g_avgTickPts > 0.0)
      s += "متوسط حركة التيك: " + DoubleToString(g_avgTickPts, 1) + " نقطة\n";
   double shownTh = (InpSpikeMinPoints > 0) ? (double)InpSpikeMinPoints : g_spikeAutoPts;
   if(shownTh > 0.0)
      s += "عتبة السبايك: " + DoubleToString(shownTh, 0) + " نقطة" + ((InpSpikeMinPoints > 0) ? " (يدوي)" : " (تلقائي)") + "\n";
   s += "سبب عدم الدخول الآن: " + EntryBlockReason() + "\n";
   s += "-----------------------------------------\n";
   s += "صفقات مفتوحة: " + IntegerToString(sellCnt) + " بيع / " + IntegerToString(buyCnt) + " شراء\n";
   if(buyCnt > 0 && g_buyEntryBar > 0 && InpBuyCandlesM1 > 0)
     {
      int remainB = InpBuyCandlesM1 - (int)((iTime(_Symbol, PERIOD_M1, 0) - g_buyEntryBar) / 60);
      if(remainB > 0)
         s += ">>> صفقة الشراء: تخرج بعد " + IntegerToString(remainB) + " شمعة دقيقة <<<\n";
     }
   s += "صفقات اليوم: " + IntegerToString(g_tradesToday) + ((InpMaxTradesPerDay > 0) ? (" / " + IntegerToString(InpMaxTradesPerDay)) : " (بلا حد)") + "\n";
   s += "الفاصل بين الصفقات: " + ((InpMinSecondsBetween > 0) ? (IntegerToString(InpMinSecondsBetween / 60) + " دقيقة") : "معطل") + "\n";
   s += "التوقف بعد الخسارة: " + ((InpLossCooldownMin > 0) ? (IntegerToString(InpLossCooldownMin) + " دقيقة") : "معطل - البوت يعمل دائماً") + "\n";
   if(!LossCooldownOK())
     {
      long remSec = (long)InpLossCooldownMin * 60 - (long)(TimeCurrent() - g_lastCloseTime);
      if(remSec > 0)
         s += ">>> انتظار بعد الخسارة: باقي " + IntegerToString((int)MathCeil(remSec / 60.0)) + " دقيقة <<<\n";
     }
   if(g_lastSpikeTime > 0)
      s += "آخر سبايك هابط: " + TimeToString(g_lastSpikeTime, TIME_DATE | TIME_MINUTES) + "\n";
   if(g_halted)
      s += ">>> متوقف اليوم: بلغ حد الخسارة اليومية <<<\n";
   s += "=========================================";

   Comment(s);
  }

//+------------------------------------------------------------------+
//| التهيئة                                                          |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 1) يعمل على PainX فقط
   string ls = _Symbol;
   StringToLower(ls);
   if(StringFind(ls, "pain") < 0)
     {
      Alert("PainX EA: هذا الإكسبيرت مخصص لـ PainX فقط. الرمز الحالي: " + _Symbol);
      return(INIT_PARAMETERS_INCORRECT);
     }

   // 2) متوسط الفاصل من اسم الرمز أو يدوياً
   g_avgInterval = InpAvgIntervalManual;
   long parsed = ParseIntervalFromName(_Symbol);
   if(parsed > 50)
      g_avgInterval = (int)parsed;

   // 3) التحقق من اللوت وضبطه على حدود الرمز
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   g_lot = InpFixedLot;
   if(step > 0.0)
      g_lot = MathFloor(g_lot / step) * step;
   if(g_lot < minLot)
      g_lot = minLot;
   if(g_lot > maxLot)
      g_lot = maxLot;
   if(MathAbs(g_lot - InpFixedLot) > 0.0000001)
      PrintFormat("PainX EA: تنبيه - اللوت المطلوب %.2f عدّل ليطابق حدود الرمز إلى %.2f", InpFixedLot, g_lot);

   // 4) حساب مسافتي الستوب والهدف من المبالغ الدولارية
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv <= 0.0 || ts <= 0.0)
     {
      Alert("PainX EA: بيانات قيمة التيك غير متاحة لهذا الرمز.");
      return(INIT_FAILED);
     }
   g_pointValuePos = tv * (_Point / ts) * g_lot;
   if(g_pointValuePos <= 0.0)
     {
      Alert("PainX EA: تعذر حساب قيمة النقطة لهذا الرمز.");
      return(INIT_FAILED);
     }
   if(InpStopLossUSD > 0.0)
      g_slPoints = InpStopLossUSD / g_pointValuePos;
   if(InpTakeProfitUSD > 0.0)
      g_tpPoints = InpTakeProfitUSD / g_pointValuePos;

   long   stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minPts     = (double)stopsLevel + 10.0;
   if(g_slPoints > 0.0 && g_slPoints < minPts)
     {
      PrintFormat("PainX EA: تنبيه - مسافة ستوب %.0f نقطة أقل من حد الوسيط، رُفعت إلى %.0f نقطة (الخسارة الفعلية ستكون أكبر قليلاً من %.2f$)",
                  g_slPoints, minPts, InpStopLossUSD);
      g_slPoints = minPts;
     }
   if(g_tpPoints > 0.0 && g_tpPoints < minPts)
      g_tpPoints = minPts;

   // (3.07) مسافتا ستوب وهدف الشراء
   if(InpBuyStopUSD > 0.0)
      g_buySlPoints = InpBuyStopUSD / g_pointValuePos;
   if(InpBuyTakeProfitUSD > 0.0)
      g_buyTpPoints = InpBuyTakeProfitUSD / g_pointValuePos;
   if(g_buySlPoints > 0.0 && g_buySlPoints < minPts)
      g_buySlPoints = minPts;
   if(g_buyTpPoints > 0.0 && g_buyTpPoints < minPts)
      g_buyTpPoints = minPts;

   // 5) تهيئة العداد من التاريخ
   InitFromHistory();
   if(InpEntryMode == ENTRY_CRASH_RIDE && g_avgTickPts <= 0.0)
      Print("PainX EA: تنبيه - متوسط حركة التيك غير متاح، كشف الانهيار سيستخدم عتبة افتراضية 50 نقطة.");

   // 6) تحذير ذكي لو مسافة الستوب أضيق من تقلب الرمز
   if(g_avgTickPts > 0.0 && g_slPoints > 0.0 && g_slPoints < 20.0 * g_avgTickPts)
     {
      double suggestUSD = 20.0 * g_avgTickPts * g_pointValuePos;
      PrintFormat("PainX EA: تحذير - مسافة ستوب %.2f$ (= %.0f نقطة) أضيق من تقلب الرمز (متوسط حركة التيك = %.1f نقطة). لو رفعت الخسارة إلى %.2f$ تصبح المسافة %.0f نقطة والصفقة تتنفس أفضل.",
                  InpStopLossUSD, g_slPoints, g_avgTickPts, suggestUSD, 20.0 * g_avgTickPts);
     }

   // 7) إعداد التداول
   g_trade.SetExpertMagicNumber((ulong)InpMagic);
   g_trade.SetDeviationInPoints((ulong)InpSlippagePoints);
   g_trade.SetAsyncMode(false);
   SetFillingMode();

   // 8) بداية اليوم
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   g_curDay     = dt.day_of_year;
   g_dayBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   PrintFormat("PainX EA v3.07 بدأ | الرمز=%s | بيع أساسي + شراء بعد البيع | لوت=%.2f | خسارة=%.2f$ | هدف=%.2f$ | نمط الدخول=%s | حماية الأرباح=%s | فاصل=%d ثانية | انتظار بعد خسارة=%d دقيقة",
               _Symbol, g_lot, InpStopLossUSD, InpTakeProfitUSD,
               (InpEntryMode == ENTRY_CRASH_RIDE ? "صيد الانهيار الحي" : "نافذة الاستحقاق"),
               ((InpUseBreakEven || InpUseTrailing) ? "مفعلة" : "معطلة"),
               InpMinSecondsBetween, InpLossCooldownMin);
   Print("PainX EA v3.07: كل آليات التوقف ملغاة - بلا فاصل بين الصفقات، بلا حد صفقات يومي، بلا انتظار بعد الخسارة، بلا حد خسارة يومي. البوت يعمل دائماً مهما كانت الخسارة + ستوب متحرك يحجز 75% من الربح أول بأول.");
   if(InpUseBuyAfterSell)
      PrintFormat("PainX EA v3.07: الشراء بعد البيع مفعّل - بعد إغلاق أي بيع يفتح شراء يخرج بعد %d شمعة دقيقة | ستوب الشراء=%.2f$ | حماية الأرباح (قفل تعادل + تتبع 75%) تعمل على الشراء أيضاً.", InpBuyCandlesM1, InpBuyStopUSD);
   if(InpMaxDailyLossPct <= 0.0)
      Print("PainX EA: حد الخسارة اليومي معطل بأمر المستخدم - البوت يستمر بالتداول مهما كانت الخسارة.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| الإنهاء                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
  }

//+------------------------------------------------------------------+
//| الحلقة الرئيسية                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   UpdateDailyGuard();
   UpdateTickState();
   ManagePositions();
   TryEnter();
   if(InpShowPanel)
      UpdatePanel();
  }

//+------------------------------------------------------------------+
//| تسجيل سبب إغلاق كل صفقة في سجل الخبراء                           |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol)
      return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic)
      return;

   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
      return;

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                   HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
                   HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   string reason;
   long r = HistoryDealGetInteger(trans.deal, DEAL_REASON);
   if(r == DEAL_REASON_SL)
      reason = (profit > 0.0) ? "ستوب متحرك - حماية أرباح" : "ستوب لوس";
   else if(r == DEAL_REASON_TP)
      reason = "تيك بروفت";
   else if(r == DEAL_REASON_SO)
      reason = "ستوب آوت (مارجن كول)";
   else if(r == DEAL_REASON_EXPERT)
      reason = "إغلاق بواسطة الإكسبيرت (ستوب/هدف الدولار)";
   else if(r == DEAL_REASON_CLIENT)
      reason = "إغلاق يدوي من التيرمينال";
   else if(r == DEAL_REASON_MOBILE)
      reason = "إغلاق من الموبايل";
   else
      reason = "أخرى (" + IntegerToString(r) + ")";

   // تسجيل نتيجة الإغلاق لتفعيل فترة الانتظار بعد الخسارة
   g_lastCloseTime   = TimeCurrent();
   g_lastCloseProfit = profit;

   // (3.07) نوع الصفقة القافلة: شراء = أُغلقت صفقة بيع → جهّز شراء الارتداد
   long dtype = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   if(dtype == DEAL_TYPE_BUY && InpUseBuyAfterSell)
     {
      g_buyPending = true;
      PrintFormat("PainX EA: أُغلقت صفقة بيع - فتح شراء الارتداد في التيك القادم (خروج بعد %d شمعة دقيقة، ستوب %.2f$).", InpBuyCandlesM1, InpBuyStopUSD);
     }

   PrintFormat("PainX EA: تم إغلاق صفقة %s | السبب: %s | النتيجة: %.2f %s",
               (dtype == DEAL_TYPE_BUY ? "بيع" : "شراء"), reason, profit, AccountInfoString(ACCOUNT_CURRENCY));
  }
//+------------------------------------------------------------------+
