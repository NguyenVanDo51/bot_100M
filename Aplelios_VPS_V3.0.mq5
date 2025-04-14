//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Nguyen Long Nhat ft Nguyen Van Do"
#property link      "https://www.mql5.com"
#property version   "2.1"
#include <Trade\Trade.mqh>

string VERSION = "2.1";

enum BOT_MODE
  {
   MODE_68 = 1,
   MODE_69 = 2,
   MODE_70 = 3,
   MODE_75 = 4,
   MODE_80 = 5,
   SUPER_SAFE_MODE_83 = 6,
   CUSTOM_MODE = 7
  };

enum AUTO_X_MODE
  {
   MODE_10K_X3_SL_42 = 12,
   MODE_3K_X1_SL_45 = 1,
   MODE_2K5_X1_SL_54 = 2,
   MODE_2K_X1_SL_70 = 3,
   CUSTOM = 0,
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input BOT_MODE botModeInput = MODE_69;               // MODE (Cài sẵn RSI, x2 lot với safe mode)
input AUTO_X_MODE autoXInput = MODE_10K_X3_SL_42;     // Hệ số tự đông
input bool compoundInterest = true;             // Chế độ lãi kép

input string _ = "                                                                   ";
input double TPRSIDistanceInput = 1.5;            // RSI hồi để đóng sớm Sell (70 - 5 = 65)
input double rsiSellInput = 69;                 // Ngưỡng RSI Sell
input double rsiBuyInput = 31;                  // Ngưỡng RSI Buy

input string __ = "                                                                    ";
input int xBuyInput = 1;                        // Tùy chỉnh hệ số Sell
input int xSellInput = 1;                       // Tùy chỉnh hệ số Buy

input string ___ = "                                                                  ";
input double stepPrice = 2.0;                   // Khoảng cách giá (USD)

input string ____ = "                                                                 ";
input bool isPickerballPrevention = false;         // Tự động nhận diện và Chống PickerBall
int candleStartCountPickerball = 5;               // Số nến bắt đầu tính
int candleEndCountPickerball = 5;                 // Số nến kết thúc

input string _____ = "                                                                 ";
input int delaySeconds = 50;                    // Delay time (s)
input int maxDelaySeconds = 180;                // Max Delay time (s)
input int delayTimeStep = 10;                   // Delay time step

input string ______ = "                                                                ";
input ENUM_TIMEFRAMES mainTimeframe = PERIOD_M5;
input int rsiPeriod = 14;                       // Chu kỳ RSI
input int candleNonTP = 10;                     // Số nến chốt non
input int candleTP0 = 15;                       // Số nến chốt hòa

input string _______ = "                                                                ";
input int maxOrders = 12;                       // Số lệnh tối đa
input int orderNonTP = 5;                    // Số lệnh chốt non
input int orderTP0 = 7;                      // Số lệnh chốt hòa

input string ________ = "                                                                ";
input string botTkn = "8143370585:AAF2x6KXD6qIrLXmhuz2hJO_52dA7QEMPyc"; // bot telegram token
input string chatID = "-1002349691879"; // chatID

double TPRSISell = 60;
double TPRSIBuy = 40;

BOT_MODE botMode = botModeInput;
AUTO_X_MODE autoX = autoXInput;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int xBuy = 1;                       // Hệ số Sell (10k = 3)
int xSell = 1;                      // Hệ số Buy (10k = 3)
double tpPrice;                             // Số pips chốt lời
double nontpPrice;                          // Số pips chốt lời sớm
double stoplossPip = stepPrice;     // Số pips Stoploss

const string TG_API_URL = "https://api.telegram.org";

// Khai báo Magic Number
int MAGIC_NUMBER = 123456;
double lotSizes[] =
  {
   0.01, 0.02, 0.03, 0.05, 0.07, 0.1, 0.15, 0.23, 0.34, 0.51, // 1->10
   0.76, 1.14, 1.71, 2.53, 3.84, 5.77, 8.65, 12.97
  };
//double lotSizes[] = { 0.01, 0.02, 0.03, 0.05, 0.07, 0.1, 0.5, 0.23, 0.34, 0.51, 0.76, 1.14, 1.71, 2.53, 3.84 };
// double lotSizes[] = {0.01, 0.02, 0.04, 0.08, 0.12, 0.24, 0.48, 0.96, 1.92, 2.84, 3.68};                // Mảng lot sizes
int currentBuyOrder = 0;            // Số lệnh mua hiện tại
int currentSellOrder = 0;           // Số lệnh bán hiện tại
double lastSellPrice = 0.0;
double lastBuyPrice = 0.0;

double firstOrderTime = 0.0;

CTrade trade;                       // Đối tượng giao dịch
int rsiHandle;                      // Handle RSI indicator

datetime lastOrderTime = 0;

double rsiThresholdBuy;
double rsiThresholdSell;
double maxLost = 0;

datetime expiryDate = D'2025.07.10'; // Ngày hết hạn (1 tháng, đến tháng 2 năm 2025)

//+------------------------------------------------------------------+
//| Khởi tạo                                                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   botMode = botModeInput;
   autoX = autoXInput;

   CalculateRSI(botMode);

   TPRSISell = rsiThresholdSell - TPRSIDistanceInput;
   TPRSIBuy = rsiThresholdBuy + TPRSIDistanceInput;
   tpPrice = stepPrice;                 // Số pips chốt lời
   nontpPrice = stepPrice / 2;              // Số pips chốt lời sớm
   stoplossPip = stepPrice;
   CalculateX();
   MathSrand(GetTickCount()); // Khởi tạo seed từ thời gian hệ thống
   MAGIC_NUMBER = MathRand(); // Tạo số ngẫu nhiên

// trade.SetExpertMagicNumber(MAGIC_NUMBER);

   if(TimeCurrent() >= expiryDate)
     {
      Print("This tool has expired and is no longer usable.");
      ExpertRemove();
      return INIT_FAILED;
     }

   rsiHandle = iRSI(Symbol(), mainTimeframe, rsiPeriod, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE)
     {
      Print("Error initializing RSI. Code: ", GetLastError());
      return INIT_FAILED;
     }
   Print("RSI strategy initialized.");
   return INIT_SUCCEEDED;
  }


double remoteX = 0.0;
double remoteRSI = 0.0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string lastMsg = "";

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void NotifyMessage(string msg)
  {
   if(lastMsg != msg)
     {
      SendTelegramMessage(msg);
      lastMsg = msg;
      Sleep(2000);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   double leverage = GetEffectiveLeverage();
   CheckRemoteControl(remoteX, remoteRSI);

   int rsiCode = (int)(remoteRSI * 100); // ví dụ: 0.01 → 1
   int xCode = (int)(remoteX * 100); // ví dụ: 0.05 → 5

   switch(rsiCode)
     {
      case 0:
         CalculateRSI(botModeInput);
         break;
      case 1:
         NotifyMessage("Đã tạm dừng BOT");
         Sleep(5000);
         return;
      case 2:
         CalculateRSI(MODE_75);
         break;
      case 3:
         CalculateRSI(MODE_80);
         break;
      case 4:
         CalculateRSI(SUPER_SAFE_MODE_83);
         break;
      default:
         break;
     }

   switch(xCode)
     {
      case 6:
         autoX = MODE_2K_X1_SL_70;
         CalculateX();
         break;
      default:
         if(autoX != autoXInput)
           {
            autoX = autoXInput;
            CalculateX();
           }
         break;
     }
   string xModeStr = AutoXModeToString(autoX);
   string msg = "BOT đang hoạt động | Chế độ " + BotModeToString(botMode) + " | Hệ số lot: " + xModeStr;
   NotifyMessage(msg);

   CountBuySellOrders();
   if(currentBuyOrder < 1 && currentSellOrder < 1)
     {
      firstOrderTime = 0.0;
      lastBuyPrice = 0.0;
      lastSellPrice = 0.0;
      if(compoundInterest)
        {
         CalculateX();
        }
     }

   double rsiValues[2];          // Lấy RSI của nến đóng
   double realTimeRsiValues[1];  // Lấy RSI real-time

// Lấy RSI của nến đã đóng
   if(CopyBuffer(rsiHandle, 0, 1, 1, rsiValues) <= 0)
     {
      return;
     }

// Lấy RSI real-time theo tick giá
   if(CopyBuffer(rsiHandle, 0, 0, 1, realTimeRsiValues) <= 0)
     {
      return;
     }
   GetLastOrderPrice();

   double lastRSI = rsiValues[0];      // RSI khi nến đóng
   double realTimeRSI = realTimeRsiValues[0];  // RSI real-time (đang chạy)

   double bidPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double askPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

   double spread = (askPrice - bidPrice); // Tính Spread theo đơn vị pip

   double profit = AccountInfoDouble(ACCOUNT_PROFIT);
   if(profit < maxLost)
     {
      maxLost = profit;
     }
   Comment(
      "X MODE: ", xModeStr, "\n",
      "Hệ số SELL: ", xSell, "\n",
      "Hệ số BUY: ", xBuy, "\n",

      "RSI SELL: ", rsiThresholdSell, "\n",
      "RSI BUY: ", rsiThresholdBuy, "\n",

      "TP RSI SELL: ", TPRSISell, "\n",
      "TP RSI BUY: ", TPRSIBuy, "\n",

      "Leverage 1:", leverage, "\n",

      "Đã âm tối đa: ", maxLost
   );

   bool isRisk = leverage <= 1500;

   if(currentBuyOrder >= 1 && realTimeRSI >= TPRSIBuy && profit >= 0)
     {
      CloseAllPositions();
     }

   if(currentSellOrder >= 1 && realTimeRSI <= TPRSISell && profit >= 0)
     {
      CloseAllPositions();
     }

   CheckAndClosePosBuyOnMarketDrop();
   CheckAndClosePosSellOnMarketDrop();

// bool shouldBuyRSI = (lastRSI <= rsiThresholdBuy && realTimeRSI <= lastRSI + TPRSIDistanceInput);
// bool shouldSellRSI = (lastRSI >= rsiThresholdSell && realTimeRSI >= lastRSI - TPRSIDistanceInput);
   bool shouldBuyRSI = (lastRSI <= rsiThresholdBuy && realTimeRSI <= TPRSIBuy);
   bool shouldSellRSI = (lastRSI >= rsiThresholdSell && realTimeRSI >= TPRSISell);
// Logic mua lần đầu
   if(PositionsTotal() < 1 &&
      shouldBuyRSI &&
      currentBuyOrder < 1 &&
      currentSellOrder < 1 &&
      spread < stepPrice / 2 &&
      !isRisk)
     {
      if(trade.Buy(lotSizes[currentBuyOrder] * xBuy, Symbol(), askPrice, 0, 0, "Buy " + (currentBuyOrder + 1)))
        {
         lastOrderTime = TimeCurrent();
         firstOrderTime = TimeCurrent();
        }
     }

// Logic mua các lần tiếp theo
   if(currentBuyOrder > 0 && currentBuyOrder < maxOrders)
     {
      double buyPrice = lastBuyPrice - stepPrice;
      double buyPrice2 = lastBuyPrice - stepPrice * 3;
      bool shouldOpen = (CanPlaceBuyOrder(currentBuyOrder) && askPrice <= buyPrice) || (askPrice <= buyPrice2);

      if(shouldOpen)
        {
         if(trade.Buy(lotSizes[currentBuyOrder] * xBuy, Symbol(),  askPrice, 0, 0, "Buy " + (currentBuyOrder + 1)))
           {
            lastOrderTime = TimeCurrent();
           }
        }
     }

// Logic bán lần đầu
   if(PositionsTotal() < 1 &&
      shouldSellRSI &&
      currentSellOrder < 1 &&
      currentBuyOrder < 1 &&
      spread < stepPrice / 2 &&
      !isRisk)
     {
      if(trade.Sell(lotSizes[currentSellOrder] * xSell, Symbol(), bidPrice, 0, 0, "Sell " + (currentSellOrder + 1)))
        {
         lastOrderTime = TimeCurrent();
         firstOrderTime = TimeCurrent();
        }
     }

// Logic bán các lần tiếp theo
   if(currentSellOrder > 0 && currentSellOrder < maxOrders)
     {
      double sellPrice = lastSellPrice + stepPrice; // Tính giá lệnh mới theo stepPrice
      double sellPrice2 = lastSellPrice + stepPrice * 3; // Tính giá lệnh mới theo stepPrice

      double shouldOpen = (CanPlaceBuyOrder(currentSellOrder) && bidPrice >= sellPrice) || bidPrice >= sellPrice2;
      if(shouldOpen)
        {
         if(trade.Sell(lotSizes[currentSellOrder] * xSell, Symbol(), bidPrice, 0, 0, "Sell " + (currentSellOrder + 1)))
           {
            lastOrderTime = TimeCurrent();
           }
        }
     }

   if(currentBuyOrder > 0)
     {
      double avgPriceBuy = GetAverageOpenPrice(POSITION_TYPE_BUY);
      double tpPriceBuy = tpPrice;
      int totalCandleFromL1 = CountCandlesFromTime(firstOrderTime);
      int totalCandleFromLast = CountCandlesFromTime(lastOrderTime);

      if(isPickerballPrevention == true && currentBuyOrder >= candleStartCountPickerball && totalCandleFromLast >= candleStartCountPickerball)
        {
         CloseAllPositions();
        }

      if(currentBuyOrder >= orderTP0 || totalCandleFromL1 >= candleTP0 || isRisk)
        {
         tpPriceBuy = 0;
        }
      else
        {
         if(currentBuyOrder < orderNonTP && totalCandleFromL1 < candleNonTP) // chốt bt lại 5 lệnh
           {
            tpPriceBuy = tpPrice;
           }
         else
           {
            tpPriceBuy = nontpPrice;
           }
        }
      double combinedTPBuy = avgPriceBuy + tpPriceBuy;
      SetTPForAllPositions(combinedTPBuy);
     }

// Tính TP cho lệnh bán
   if(currentSellOrder > 0)
     {
      double avgPriceSell = GetAverageOpenPrice(POSITION_TYPE_SELL);
      double tpPriceSell = tpPrice;

      int totalCandleFromL1 = CountCandlesFromTime(firstOrderTime);
      int totalCandleFromLast = CountCandlesFromTime(lastOrderTime);

      if(isPickerballPrevention == true && currentSellOrder >= candleStartCountPickerball && totalCandleFromLast >= candleStartCountPickerball)
        {
         CloseAllPositions();
        }

      if(currentSellOrder >= orderTP0 || totalCandleFromL1 >= candleTP0 || isRisk)
        {
         tpPriceSell = 0;
        }
      else
        {
         if(currentSellOrder < orderNonTP && totalCandleFromL1 < candleNonTP) // chốt bt lại 5 lệnh
           {
            tpPriceSell = tpPrice;
           }
         else
           {
            tpPriceSell = nontpPrice;
           }
        }
      double combinedTPBuy = avgPriceSell - tpPriceSell;
      SetTPForAllPositions(combinedTPBuy);
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateRSI(BOT_MODE newBotMode)
  {
   botMode = newBotMode;

   switch(botMode)
     {
      case MODE_68:
         rsiThresholdSell = 68;
         rsiThresholdBuy = 32;
         break;
      case MODE_69:
         rsiThresholdSell = 69;
         rsiThresholdBuy = 31;
         break;
      case MODE_70:
         rsiThresholdSell = 70;
         rsiThresholdBuy = 30;
         break;
      case MODE_75:
         rsiThresholdSell = 75;
         rsiThresholdBuy = 25;
         break;
      case MODE_80:
         rsiThresholdSell = 80;
         rsiThresholdBuy = 20;
         break;
      case SUPER_SAFE_MODE_83:
         rsiThresholdSell = 83;
         rsiThresholdBuy = 17;
         break;
      case CUSTOM_MODE:
         rsiThresholdBuy = rsiBuyInput;
         rsiThresholdSell = rsiSellInput;
         break;
      default:
         rsiThresholdBuy = rsiBuyInput;
         rsiThresholdSell = rsiSellInput;
         break;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateX()
  {
   if(autoX == CUSTOM)
     {
      xBuy = xBuyInput;
      xSell = xSellInput;
      return;
     }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(currentBuyOrder < 1 && currentSellOrder < 1)
     {
      switch(autoX)
        {
         case MODE_3K_X1_SL_45:
            xBuy = int(balance / 3000);
            xSell = int(balance / 3000);
            break;
         case MODE_10K_X3_SL_42:
            xBuy = int(balance / 3333);
            xSell = int(balance / 3333);
            break;
         case MODE_2K5_X1_SL_54:
            xBuy = int(balance / 2500);
            xSell = int(balance / 2500);
            break;
         case MODE_2K_X1_SL_70:
            xBuy = int(balance / 2000);
            xSell = int(balance / 2000);
            break;
         case CUSTOM:
            xBuy = xBuyInput;
            xSell = xSellInput;
            break;
         default:
            xBuy = xBuyInput;
            xSell = xSellInput;
            break;
        }
     }
   if(botMode == SUPER_SAFE_MODE_83)
     {
      xBuy = xBuy * 2;
      xSell = xSell * 2;
     }
   if(xBuy > 175)
     {
      xBuy = 175;
     }
   if(xSell > 175)
     {
      xSell = 175;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string BotModeToString(BOT_MODE mode)
  {
   switch(mode)
     {
      case MODE_68:
         return "Mode 68";
      case MODE_69:
         return "MẶC ĐỊNH";
      case MODE_70:
         return "MODE 70";
      case MODE_75:
         return "AN TOÀN";
      case MODE_80:
         return "SIÊU AN TOÀN";
      case SUPER_SAFE_MODE_83:
         return "AN TOÀN TUYỆT ĐỐI";
      case CUSTOM_MODE:
         return "TÙY CHỈNH";
      default:
         return "Unknown Mode";
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string AutoXModeToString(AUTO_X_MODE mode)
  {
   switch(mode)
     {
      case MODE_10K_X3_SL_42:
         return "10K X3 SL 42%";
      case MODE_3K_X1_SL_45:
         return "3K X1 SL 45%";
      case MODE_2K5_X1_SL_54:
         return "2.5K X1 SL 54%";
      case MODE_2K_X1_SL_70:
         return "2K X1 SL 70%";
      case CUSTOM:
         return "TÙY CHỈNH";
      default:
         return "Unknown Mode";
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CountBuySellOrders()
  {
   int buyCount = 0;
   int sellCount = 0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == Symbol())
        {
         int type = PositionGetInteger(POSITION_TYPE);
         if(type == POSITION_TYPE_BUY)
            buyCount++;
         else
            if(type == POSITION_TYPE_SELL)
               sellCount++;
        }
     }

   currentBuyOrder = buyCount;
   currentSellOrder = sellCount;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GetLastOrderPrice()
  {
   double lastBuyP = 0.0;
   double lastSellP = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == Symbol())
        {
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
            if(openPrice <= lastBuyP || lastBuyP == 0.0)
               lastBuyP = openPrice;
           }
         else
           {
            if(openPrice >= lastSellP || lastSellP == 0.0)
              {
               lastSellP = openPrice;
              }
           }
        }
     }
   lastSellPrice = lastSellP;
   lastBuyPrice = lastBuyP;
  }

// Hàm đếm số nến từ lệnh đầu tiên đến hiện tại
int CountCandlesFromTime(double orderTime)
  {
   if(orderTime == 0.0)
      return 0;

   int firstCandleIndex = iBarShift(Symbol(), mainTimeframe, orderTime);
   int currentCandleIndex = iBarShift(Symbol(), mainTimeframe, TimeCurrent());

   return firstCandleIndex - currentCandleIndex; // Số nến đã trôi qua
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckRemoteControl(double &remoteX, double &remoteRSI)
  {
   remoteX = 0.0;
   remoteRSI = 0.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);

      if(OrderSelect(ticket))
        {
         if(OrderGetString(ORDER_SYMBOL) == Symbol())
           {
            ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

            if(type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT)
              {
               double lots = OrderGetDouble(ORDER_VOLUME_CURRENT);

               if(lots <= 0.05)
                 {
                  remoteRSI = lots;
                 }
               else
                  if(lots > 0.05)
                    {
                     remoteX = lots;
                    }
              }
           }
        }
     }
  }



// Hàm tính giá mở trung bình của các lệnh theo từng chiều
double GetAverageOpenPrice(int orderType)
  {
   double totalPrice = 0.0;
   double totalLots = 0.0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_TYPE) == orderType)
        {
         double lotSize = PositionGetDouble(POSITION_VOLUME);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         totalPrice += openPrice * lotSize;
         totalLots += lotSize;
        }
     }

   if(totalLots == 0)
      return 0; // Không có lệnh nào

   return totalPrice / totalLots; // Giá trung bình
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CanPlaceBuyOrder(int countOrder)
  {
   int newDelaySeconds = MathMin((countOrder * delayTimeStep) + delaySeconds, maxDelaySeconds);

   return (TimeCurrent() - lastOrderTime >= newDelaySeconds);
  }
//+------------------------------------------------------------------+
//| Đóng tất cả các lệnh                                             |
//+------------------------------------------------------------------+
void CloseAllPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == _Symbol && PositionGetString(POSITION_SYMBOL) == Symbol())
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
           {
            trade.PositionClose(ticket);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Set TP all                                         |
//+------------------------------------------------------------------+
void SetTPForAllPositions(double tpPrice)
  {
// Làm tròn tpPrice theo số thập phân của symbol hiện tại
   double normalizedTP = NormalizeDouble(tpPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      // Lấy ticket của lệnh
      ulong ticket = PositionGetTicket(i);

      // Chọn lệnh bằng ticket
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == Symbol())
        {
         double slPrice = PositionGetDouble(POSITION_SL); // Lấy mức SL hiện tại
         double currentTPPrice = PositionGetDouble(POSITION_TP); // Lấy mức TP hiện tại

         // Làm tròn TP hiện tại để so sánh chính xác
         currentTPPrice = NormalizeDouble(currentTPPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

         // Nếu TP đã đúng thì bỏ qua
         if(normalizedTP == currentTPPrice)
            continue;

         // Chỉnh sửa TP cho lệnh
         if(!trade.PositionModify(ticket, slPrice, normalizedTP))
           {
            // Print("❌ Failed to set TP for position with ticket: ", ticket, ", Error: ", GetLastError());
           }
         else
           {
            // Print("✅ Đã setting TP cho lệnh bot: ", ticket, " tại giá: ", normalizedTP);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetSLForAllPositions(double slPrice)
  {
   int totalToSet = 0;       // Số lệnh cần set SL
   int totalSetSuccess = 0;  // Số lệnh đã set SL thành công

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == Symbol())
        {
         double tpPrice = PositionGetDouble(POSITION_TP);
         double currentSLPrice = PositionGetDouble(POSITION_SL);

         // Nếu SL đã đúng thì bỏ qua
         if(slPrice == currentSLPrice)
            continue;

         totalToSet++;

         if(!trade.PositionModify(ticket, slPrice, tpPrice))
           {
            Print("❌ Failed to set SL for position with ticket: ", ticket, ", Error: ", GetLastError());
           }
         else
           {
            Print(" Đã Setting SL cho lệnh bot: ", ticket, " tại giá: ", slPrice);
            totalSetSuccess++;
           }
        }
     }

// Nếu tất cả lệnh cần set SL đều thành công
   if(totalToSet > 0 && totalSetSuccess == totalToSet)
     {
      Print("Đã set SL cho TẤT CẢ ", totalSetSuccess, " lệnh - Dừng EA");
      // ExpertRemove();
     }
   else
      if(totalToSet > 0)
        {
         Print("️ Chỉ set SL thành công ", totalSetSuccess, "/", totalToSet, " lệnh. EA vẫn tiếp tục chạy.");
        }
      else
        {
         Print("️ Không có lệnh nào cần set SL.");
        }
  }

//+------------------------------------------------------------------+
//| Kiểm tra và đóng toàn bộ lệnh Buy
//+------------------------------------------------------------------+
void CheckAndClosePosBuyOnMarketDrop()
  {
   if(currentBuyOrder >= maxOrders) // Kiểm tra đã vào đủ số lệnh tối đa chưa
     {
      SetSLForAllPositions(lastBuyPrice - stoplossPip);
     }
  }
//+------------------------------------------------------------------+
//| Kiểm tra và đóng toàn bộ lệnh Sell
//+------------------------------------------------------------------+
void CheckAndClosePosSellOnMarketDrop()
  {
   if(currentSellOrder >= maxOrders) // Kiểm tra đã vào đủ số lệnh tối đa chưa
     {
      SetSLForAllPositions(lastSellPrice + stoplossPip);
     }
  }


//+------------------------------------------------------------------+
//| Hủy bỏ                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(rsiHandle != INVALID_HANDLE)
     {
      IndicatorRelease(rsiHandle);
     }
   Comment("EA đã dừng. Lỗ tối đa: ", maxLost);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SendTelegramMessage(string msg)
  {

   char data[];  // Array to hold data to be sent in the web request (empty in this case)
   char res[];  // Array to hold the response data from the web request
   string resHeaders;  // String to hold the response headers from the web request

   string accountName = AccountInfoString(ACCOUNT_NAME); // Hoặc dùng ACCOUNT_LOGIN nếu muốn ID
   string fullMsg = "[" + accountName + "] " + msg;
   const string url = TG_API_URL + "/bot" + botTkn + "/sendmessage?chat_id=" + chatID +
                      "&text=" + fullMsg;

// Send the web request to the Telegram API
   int send_res = WebRequest("POST", url, "", 10000, data, res, resHeaders);

// Check the response status of the web request
   if(send_res == 200)
     {
      // If the response status is 200 (OK), print a success message
      Print("TELEGRAM MESSAGE SENT SUCCESSFULLY");
     }
   else
      if(send_res == -1)
        {
         // If the response status is -1 (error), check the specific error code
         if(GetLastError() == 4014)
           {
            // If the error code is 4014, it means the Telegram API URL is not allowed in the terminal
            Print("PLEASE ADD THE ", TG_API_URL, " TO THE TERMINAL");
           }
         // Print a general error message if the request fails
         Print("UNABLE TO SEND THE TELEGRAM MESSAGE");
        }
      else
         if(send_res != 200)
           {
            // If the response status is not 200 or -1, print the unexpected response code and error code
            Print("UNEXPECTED RESPONSE ", send_res, " ERR CODE = ", GetLastError());
           }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetEffectiveLeverage()
  {
   double lot = 1.0;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double margin=EMPTY_VALUE;

   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lot, price, margin))
     {
      Print("OrderCalcMargin() failed. Error ", GetLastError());
     }

   double contract_value = lot * 100.0 * price; // XAUUSD: 100 oz mỗi lot
   return MathRound(contract_value / margin);
  }
//+------------------------------------------------------------------+
