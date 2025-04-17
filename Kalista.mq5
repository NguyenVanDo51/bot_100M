//+------------------------------------------------------------------+

//|                                                      ProjectName |

//|                                      Copyright 2020, CompanyName |

//|                                       http://www.companyname.net |

//+------------------------------------------------------------------+

#include <Trade/Trade.mqh>
CTrade trade;


input double x = 1;                           // Hệ số lot/vốn (100k = hệ số 1)

double lotSizeMulipler = 1.2;          // Hệ số dãn LotSize
input int maxStopLossUSD = 19000;            // USD cắt lỗ
input int tpNotProfitOrder = 15;             // Lệnh cầu hòa
input int orderSeconds = 1;                 // Số giây tối thiểu giữa các lệnh
input double tpPips = 50;                // pip cho lai
double stepPips = 30;              // Step pips
double increaseStepPips = 3;     // phan tram tang giua cac lenh
input double stepPipRound1 = 30;
input double stepPipRound2 = 100;
input double stepPipRound3 = 150;

// btc ~ 20-25%

// input double lotSizeMulipler = 1.2;          // Hệ số dãn LotSize
// input int maxStopLossUSD = 90000;            // USD cắt lỗ
// input int tpNotProfitOrder = 15;             // Lệnh cầu hòa
// input int stopBotStart = 11;                 // giờ dừng bot (GMT 0)
// input int stopBotEnd = 11;                   // giờ chạy lại bot (GMT 0)
// input int orderSeconds = 30;                 // Số giây tối thiểu giữa các lệnh
// input double tpPercent = 0.02;                // Phan tram gia chot lai
// input double stepPercent = 0.04;              // phan tram gia giua cac lenh

input int magicNumber = 130998;              // Magic Number để nhận diện lệnh bot đặt

int count_sell = 0, count_buy = 0;

double lotSizes[200] =
  {
   0.01, 0.01, 0.01, 0.01, 0.01, 0.01,
   0.02, 0.02, 0.02, 0.02, 0.02, 0.02,
   0.03, 0.03, 0.03, 0.03, 0.03,
   0.04, 0.04, 0.04, 0.05, 0.05, 0.05,
   0.06, 0.06, 0.06,
   0.07, 0.07, 0.08, 0.08, 0.09, 0.09,
   0.10, 0.11, 0.12, 0.13, 0.14, 0.15,
   0.16, 0.17, 0.19,
   0.20, 0.22, 0.23, 0.25, 0.27, 0.29,
   0.30, 0.32, 0.34, 0.35, 0.37, 0.38,
   0.40, 0.41, 0.43, 0.44, 0.47, 0.48,
   0.51, 0.56, 0.60, 0.65, 0.70, 0.76,
   0.82, 0.88, 0.95,
   1.03, 1.11, 1.20, 1.29, 1.33, 1.53, 1.76,
   2.03, 2.33,
  };
double lotSize1 = 0.01;        // Lot Size cho lệnh đầu
datetime lastBuyTime = 0;

// l2 = l1 * 1.2



//+------------------------------------------------------------------+

//|                                                                  |

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizeVolume(double volume)
  {
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double normalizedVolume = round(volume / lotStep) * lotStep;

   if(normalizedVolume < minLot)
      normalizedVolume = minLot;

   if(normalizedVolume > maxLot)
      normalizedVolume = maxLot;

   return normalizedVolume;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(magicNumber);
   for(int i = 0; i < 200; i++)
     {
      lotSizes[i] = lotSizes[i] * x;
     }
   return(INIT_SUCCEEDED);
  }



// Hàm kiểm tra số lệnh đang mở

int CountOrders(int type)

  {

   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == magicNumber)
        {
         if(PositionGetInteger(POSITION_TYPE) == type)
            count++;
        }
     }

   return count;

  }



// Hàm lấy giá lệnh mới nhất theo loại lệnh

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetLastOrderPrice(int type)
  {
   double lastBuyPrice = 0.0;
   double lastSellPrice = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == magicNumber)
        {
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
            if(openPrice <= lastBuyPrice || lastBuyPrice == 0.0)
               lastBuyPrice = openPrice;
           }
         else
           {
            if(openPrice >= lastSellPrice || lastSellPrice == 0.0)
              {
               lastSellPrice = openPrice;
              }
           }
        }
     }

   double bidPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double askPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

   if(type == POSITION_TYPE_BUY)
      return lastBuyPrice != 0.0 ? lastBuyPrice : askPrice;

   return lastSellPrice != 0.0 ? lastSellPrice : bidPrice;

  }

// Hàm tính giá mở trung bình của các lệnh theo từng chiều
double GetAverageOpenPrice(int orderType)
  {
   double totalPrice = 0.0;
   double totalLots = 0.0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == magicNumber && PositionGetInteger(POSITION_TYPE) == orderType)
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


// Cập nhật TP cho từng lệnh dựa trên giá trung bình
void UpdateTakeProfit(ENUM_ORDER_TYPE targerOrderType)
  {
   double avgPriceSell = GetAverageOpenPrice(POSITION_TYPE_SELL);
   double avgPriceBuy = GetAverageOpenPrice(POSITION_TYPE_BUY);
   double pointValue = _Point * (SymbolInfoInteger(Symbol(), SYMBOL_DIGITS) == 3 || SymbolInfoInteger(Symbol(), SYMBOL_DIGITS) == 5 ? 10 : 1);

   double tpSell = avgPriceSell;
   double tpBuy = avgPriceBuy;

// % TP

   double tpValue = (tpPips * pointValue);

   if(count_sell < tpNotProfitOrder)
     {
      tpSell = avgPriceSell - tpValue;
     }
   else
     {
      tpSell = avgPriceSell;
     }

   if(count_buy < tpNotProfitOrder)
     {
      tpBuy = avgPriceBuy + tpValue;
     }
   else
     {
      tpBuy = avgPriceBuy;
     }

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == magicNumber)
        {
         int orderType = PositionGetInteger(POSITION_TYPE);
         int currentTP = PositionGetDouble(POSITION_TP);

         if(targerOrderType == orderType && orderType == POSITION_TYPE_SELL)
           {
            if(tpSell > 0 && tpSell != currentTP)  // Chỉ cập nhật nếu TP hợp lệ
              {
               trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), tpSell);
              }
           }

         if(targerOrderType == orderType && orderType == POSITION_TYPE_BUY)
           {
            if(tpBuy > 0 && tpBuy != currentTP)  // Chỉ cập nhật nếu TP hợp lệ
              {
               trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), tpBuy);
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CanPlaceBuyOrder()
  {
   return (TimeCurrent() - lastBuyTime >= orderSeconds); // Nếu cách nhau >= 30 giây thì cho vào lệnh
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageOrders()
  {
   if(!CanPlaceBuyOrder())
      return;

   double lastSellPrice = GetLastOrderPrice(ORDER_TYPE_SELL);
   double lastBuyPrice = GetLastOrderPrice(ORDER_TYPE_BUY);

   double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double askPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double pointValue = _Point * (SymbolInfoInteger(Symbol(), SYMBOL_DIGITS) == 3 || SymbolInfoInteger(Symbol(), SYMBOL_DIGITS) == 5 ? 10 : 1);
   double currentPrice = bidPrice;

// Lấy giá đóng cửa của ngày trước (khung 4H)
   double previousClose = iClose(_Symbol, PERIOD_H1, 1);  // 6 cây nến 4H trước

// Chuyển từ % sang giá trị thực

   double stepPipsSell = stepPipRound1;

   if(count_sell > 12)
     {
      stepPipsSell = stepPipRound2;
     }
   if(count_sell > 26)
     {
      stepPipsSell = stepPipRound3;
     }

   double stepSellValue = stepPipsSell * pointValue;

   Print("previousClose: ", previousClose, ", stepSellValue: ", stepSellValue);

// Kiểm tra và đặt lệnh SELL nếu giá tăng %
   if(count_sell == 0 || bidPrice >= lastSellPrice + stepSellValue)
     {
      double sellLot = lotSizes[count_sell];
      string comment = "DCA Sell " + IntegerToString(count_sell + 1) + ", Pips: " + stepPipsSell;
      if(trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, sellLot, bidPrice, 0, 0, comment))
        {
         lastBuyTime = TimeCurrent();
         UpdateTakeProfit(ORDER_TYPE_SELL);
        }
     }

   double stepPipsBuy = stepPipRound1;

   if(count_buy > 12)
     {
      stepPipsBuy = stepPipRound2;
     }
   if(count_buy > 27)
     {
      stepPipsBuy = stepPipRound3;
     }

   double stepBuyValue = stepPipsBuy * pointValue;

// Kiểm tra và đặt lệnh BUY nếu giá giảm stepPercent %
   if(count_buy == 0 || askPrice <= lastBuyPrice - stepBuyValue)
     {
      double buyLot = lotSizes[count_buy];
      string comment = "DCA Buy " + IntegerToString(count_buy + 1)  + ", Pips: " + stepPipsBuy;
      if(trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, buyLot, askPrice, 0, 0, comment))
        {
         lastBuyTime = TimeCurrent();
         UpdateTakeProfit(ORDER_TYPE_BUY);
        }

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
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == magicNumber)
        {
         int type = PositionGetInteger(POSITION_TYPE);
         if(type == POSITION_TYPE_BUY)
            buyCount++;
         else
            if(type == POSITION_TYPE_SELL)
               sellCount++;
        }
     }

   count_buy = buyCount;
   count_sell = sellCount;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAllPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == magicNumber)
        {
         trade.PositionClose(ticket);
         Print("Closed position with ticket: ", ticket);
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   CountBuySellOrders();

   double profit = AccountInfoDouble(ACCOUNT_PROFIT);

   if(profit < maxStopLossUSD * x * -1)
     {
      CloseAllPositions();
      CloseAllPositions();
      ExpertRemove();
      return;
     }
   ManageOrders();
  }
//+------------------------------------------------------------------+
