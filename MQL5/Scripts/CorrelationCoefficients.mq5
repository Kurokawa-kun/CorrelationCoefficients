//+------------------------------------------------------------------+
//|                                      CorrelationCoefficients.mq5 |
//|                                         Copyright 2024, Kurokawa |
//|                                   https://twitter.com/ImKurokawa |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Kurokawa"
#property link      "https://twitter.com/ImKurokawa"
#property version   "1.00"
#property script_show_inputs
#include <Generic\ArrayList.mqh>
#include <Generic\SortedSet.mqh>
#include <CheckEnvironment.mqh>
#define Threshold       0.30  //  相関係数の絶対値が1-Threshold以上のものを強い相関、Threshold/2以内に収まっているものを相関なしと判断する

//  パラメータ
input bool IgnoreCrossCurrencies = true;
input int MaximumNumberOfItems = 5;
input ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT;
input int PeriodOfTime = 500;

void OnStart()
{
   PrintFormat("Starting...");
   
   //  環境のチェック
   if (!CheckEnvironment(ChkConnection, NULL, NULL, NULL, NULL))
   {
      PrintFormat("Failed!");
      return;
   }
   
   //  時間足がPERIOD_CURRENTの場合は現在の時間足を代入する
   ENUM_TIMEFRAMES CurrentTimeFrame;
   if (TimeFrame == PERIOD_CURRENT)
   {
      CurrentTimeFrame = Period();
   }
   else
   {
      CurrentTimeFrame = TimeFrame;
   }
   
   //  対象となるシンボルを選ぶ
   PrintFormat("Checking target symbol data...");
   CArrayList<string> *ListSymbols = new CArrayList<string>();   
   for (int i = 0; i < SymbolsTotal(true); i++)
   {
      string sn = SymbolName(i, true);
      
      //  クロス通貨をスキップする設定になっている場合の処理
      if (SymbolInfoString(sn, SYMBOL_SECTOR_NAME) == "Currency" && IgnoreCrossCurrencies && SymbolInfoString(sn, SYMBOL_CURRENCY_BASE) != "USD" && SymbolInfoString(sn, SYMBOL_CURRENCY_PROFIT) != "USD")
      {
         continue;
      }
      if (SymbolInfoString(sn, SYMBOL_SECTOR_NAME) == "Crypto Currency" && IgnoreCrossCurrencies && SymbolInfoString(sn, SYMBOL_CURRENCY_BASE) != "USD" && SymbolInfoString(sn, SYMBOL_CURRENCY_PROFIT) != "USD")
      {
         continue;
      }
      
      //  対象シンボルのチャートが読めるか事前にチェックする
      //  対象期間の1.4倍を調べる必要がある理由は仮想通貨のような土日も含まれるシンボルを平日だけのシンボルと比較するケースがあるため
      if (!CheckTickData(sn, CurrentTimeFrame, (int)(PeriodOfTime * 1.4)))
      {
         //  一部でもチャートデータが読み取れなかった場合は計算対象から除外する
         PrintFormat("ERROR! Symbol '%s' was ignored because it doesn't contain some or all of %d candle data in %s timeframe. Try to show it on the chart window beforehand.", sn, PeriodOfTime, EnumToString(CurrentTimeFrame));
         continue;
      }
      
      ListSymbols.Add(sn);
   }
   
   //  チャートデータを格納するためのバッファを初期化する
   double ChartData1[];
   ArrayResize(ChartData1, PeriodOfTime, 0);
   double ChartData2[];
   ArrayResize(ChartData2, PeriodOfTime, 0);
   
   //  相関係数を格納するためのセット
   CSortedSet<string> *SetPlusCorrelationCoefficients = new CSortedSet<string>();
   CSortedSet<string> *SetMinusCorrelationCoefficients = new CSortedSet<string>();
   CSortedSet<string> *SetAbsCorrelationCoefficients = new CSortedSet<string>();
   
   int Combination = (int)(ListSymbols.Count() / 2.0 * (1 + ListSymbols.Count()) - ListSymbols.Count());
   PrintFormat("Calculating total %d correlation coefficients induced from %d symbols...", Combination, ListSymbols.Count());
   
   int v=0;
   //  相関係数の計算
   for (int a = 0; a < ListSymbols.Count() - 1; a++)
   {
      for (int b = a + 1; b < ListSymbols.Count(); b++)
      {
         string sa;
         ListSymbols.TryGetValue(a, sa);
         string sb;
         ListSymbols.TryGetValue(b, sb);
         CopyChartData(sa, sb, CurrentTimeFrame, PeriodOfTime, ChartData1, ChartData2);
         
         double Correlation = NormalizeDouble(CorrelationCoefficient(ChartData1, ChartData2), 4);
         double AbsCorrelation = MathAbs(Correlation);
         if (Correlation >= 0 && Correlation >= (1.00 - Threshold))
         {
            SetPlusCorrelationCoefficients.Add(StringFormat("%+.4f, %+.4f, %s vs %s", Correlation, Correlation, sa, sb));
         }
         else if (Correlation < 0 && Correlation <= -1 * (1.00 - Threshold))
         {
            SetMinusCorrelationCoefficients.Add(StringFormat("%+.4f, %+.4f, %s vs %s", Correlation, Correlation, sa, sb));
         }
         if (AbsCorrelation <= (Threshold / 2))
         {
            SetAbsCorrelationCoefficients.Add(StringFormat("%+.4f, %+.4f, %s vs %s", AbsCorrelation, Correlation, sa, sb));
         }
         v++;
      }
   }
   
   //  バッファの解放
   ArrayFree(ChartData1);   
   ArrayFree(ChartData2);
   
   //  結果の表示
   PrintFormat("********************  RESULTS  ********************");
   PrintFormat("Number of symbols: %d", ListSymbols.Count());
   PrintFormat("Number of correlation coefficients: %d", Combination);
   PrintFormat("Timeframe: %s", EnumToString(CurrentTimeFrame));
   PrintFormat("Period of time: %d bars", PeriodOfTime);
   
   //  ソートされた結果を格納する
   string SortedCorrelationCoefficients[];   
   ArrayResize(SortedCorrelationCoefficients, SetPlusCorrelationCoefficients.Count(), 0);
   SetPlusCorrelationCoefficients.CopyTo(SortedCorrelationCoefficients);
   
   PrintFormat("Combinations of symbols with strong positive correlation:");
   for (int c = 0; c < MaximumNumberOfItems; c++)
   {
      if (ArraySize(SortedCorrelationCoefficients) - 1 - c < 0) break;
      string msg = SortedCorrelationCoefficients[ArraySize(SortedCorrelationCoefficients) - 1 - c];
      PrintFormat("  %s", StringSubstr(msg, StringFind(msg, ",") + 2));
   }
   
   ArrayResize(SortedCorrelationCoefficients, SetMinusCorrelationCoefficients.Count(), 0);
   SetMinusCorrelationCoefficients.CopyTo(SortedCorrelationCoefficients);
      
   PrintFormat("Combinations of symbols with strong negative correlation:");
   for (int c = 0; c < MaximumNumberOfItems; c++)
   {
      if (ArraySize(SortedCorrelationCoefficients) - 1 - c < 0) break;
      string msg = SortedCorrelationCoefficients[ArraySize(SortedCorrelationCoefficients) - 1 - c];
      PrintFormat("  %s", StringSubstr(msg, StringFind(msg, ",") + 2));
   }
   
   ArrayResize(SortedCorrelationCoefficients, SetAbsCorrelationCoefficients.Count(), 0);
   SetAbsCorrelationCoefficients.CopyTo(SortedCorrelationCoefficients);
   
   PrintFormat("Combinations of symbols with no correlation:");
   for (int c = 0; c < MaximumNumberOfItems; c++)
   {
      if (ArraySize(SortedCorrelationCoefficients) <= c) break;
      string msg = SortedCorrelationCoefficients[c];
      PrintFormat("  %s", StringSubstr(msg, StringFind(msg, ",") + 2));
   }
   
   //  メモリの解放
   ArrayFree(SortedCorrelationCoefficients);
   delete ListSymbols;
   delete SetMinusCorrelationCoefficients;
   delete SetPlusCorrelationCoefficients;
   delete SetAbsCorrelationCoefficients;
   
   PrintFormat("Done.");
   return;
}

//  チックデータのチェック
bool CheckTickData(string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
   for (int i = 0; i < period; i++)
   {
      if (iOpen(symbol, timeframe, i) == 0 || iHigh(symbol, timeframe, i) == 0 || 
         iLow(symbol, timeframe, i) == 0 || iClose(symbol, timeframe, i) == 0)
      {
         return false;
      }
   }
   return true;
}

//  バッファにチャートデータをコピーする
void CopyChartData(string Symbol1, string Symbol2, ENUM_TIMEFRAMES CurrentTimeFrame, int NumberOfBars, double& ChartData1[], double& ChartData2[])
{
   int Shift1 = 0;
   int Shift2 = 0;
   
   for (int c = 0; c < NumberOfBars; c++)
   {
      datetime Time1 = iTime(Symbol1, CurrentTimeFrame, Shift1);
      datetime Time2 = iTime(Symbol2, CurrentTimeFrame, Shift2);
      //  チャートの種別（株、債権、CFD、FX、仮想通貨）によってチャートデータの時間が異なる場合があるため、差異がある場合はここで調整する
      while (Time1 != Time2)
      {
         if (Time1 > Time2) Shift1++;
         else Shift2++;
         Time1 = iTime(Symbol1, CurrentTimeFrame, Shift1);
         Time2 = iTime(Symbol2, CurrentTimeFrame, Shift2);      
      }      
      ChartData1[c] = iClose(Symbol1, CurrentTimeFrame, Shift1);
      ChartData2[c] = iClose(Symbol2, CurrentTimeFrame, Shift2);
      Shift1++;
      Shift2++;
   }
}

//  相関係数
double CorrelationCoefficient(double &A[], double &B[])
{
   return Covariance(A, B) / (StandardDeviation(A) * StandardDeviation(B));
}

//  共分散
double Covariance(double &A[], double &B[])
{
   if (ArraySize(A) != ArraySize(B))
   {
      PrintFormat("ERROR! Failed to calculate covariance because specified two array sizes are different.");
      return 0;
   }
   if (ArraySize(A)==0 || ArraySize(B)==0)
   {
      PrintFormat("ERROR! Failed to calculate covariance because array size is 0.");
      return 0;
   }
   
   //  共分散の計算
   double AverageA = Average(A);
   double AverageB = Average(B);   
   double t = 0;
   for (int i = 0; i < ArraySize(A); i++)
   {
      t += (A[i] - AverageA) * (B[i] - AverageB);
   }
   return t / ArraySize(A);
}

//  標準偏差
double StandardDeviation(double &A[])
{
   if (ArraySize(A) == 0)
   {
      PrintFormat("ERROR! Failed to calculate standard deviation because array size is 0.");
      return 0;
   }
   return MathSqrt(Variance(A));
}

//  平均
double Average(double &A[])
{
   if (ArraySize(A) == 0)
   {
      PrintFormat("ERROR! Failed to calculate average because array size is 0.");
      return 0;
   }
   double t = 0;
   for (int i = 0; i < ArraySize(A); i++)
   {
      t += A[i];
   }
   return t / ArraySize(A);
}

//  分散
double Variance(double &A[])
{
   if (ArraySize(A) == 0)
   {
      PrintFormat("ERROR! Failed to calculate variance because array size is 0.");
      return 0;
   }
   double AverageA = Average(A);
   double t = 0;
   for (int i = 0; i < ArraySize(A); i++)
   {
      t += MathPow((A[i] - AverageA), 2);
   }
   return t / ArraySize(A);
}
