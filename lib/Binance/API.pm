package Binance::API;

# MIT License
#
# Copyright (c) 2018 Lari Taskula  <lari@taskula.fi>, Filip La Gre <tutenhamond@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

use strict;
use warnings;

use Carp;
use Scalar::Util qw( blessed );

use Binance::API::Logger;
use Binance::API::Request;

use Binance::Exception::Parameter::Required;

our $VERSION = '1.00';

=head1 NAME

Binance::API

=head1 DESCRIPTION

This module provides a Perl implementation for Binance API

Binance API documentation: C<https://www.binance.com/restapipub.html>.

ENUM definitions:
https://www.binance.com/restapipub.html#user-content-enum-definitions

=head1 SYNOPSIS

use Binance::API;

my $api = Binance::API->new(
    apiKey    => 'my_api_key',
    secretKey => 'my_secret_key',
);

my $ticker = $api->ticker( symbol => 'ETHBTC' );

=head1 METHODS

=cut

=head2 new

my $api = Binance::API->new(
    apiKey    => 'my_api_key',
    secretKey => 'my_secret_key',
);

Instantiates a new Binance::API object

PARAMETERS:
- apiKey     [OPTIONAL] Your Binance API key
- secretKey  [OPTIONAL] Your Binance API secret key
- recvWindow [OPTIONAL] Number of milliseconds the request is valid for
- logger     [OPTIONAL] A logger object that implements (at least) debug, warn,
                        error, fatal level logging. Log::Log4perl recommended.

RETURNS:
    A Binance::API object

=cut

sub new {
    my ($class, %params) = @_;

    my $logger = Binance::API::Logger->new($params{logger});

    my $ua = Binance::API::Request->new(
        apiKey     => $params{apiKey},
        secretKey  => $params{secretKey},
        recvWindow => $params{recvWindow},
        logger     => $logger,
    );

    my $self = {
        ua         => $ua,
        logger     => $logger,
    };

    bless $self, $class;
}

=head2 ping

$api->ping();

Test connectivity to the Rest API

PARAMETERS:
    NONE

RETURNS:
1 if successful, otherwise 0

=cut

sub ping {
    return keys %{$_[0]->ua->get('/api/v1/ping')} == 0 ? 1 : 0;
}

=head2 Check server time

$api->time();

Test connectivity to the Rest API and get the current server time.

PARAMETERS:
    NONE

RETURNS:
    Server (epoch) time in milliseconds

=cut

sub time {
    my $self = shift;

    my $time = $self->ua->get('/api/v1/time');
    return exists $time->{serverTime} ? $time->{serverTime} : 0;
}

=head2 Exchange information

$api->exchangeInfo();

Current exchange trading rules and symbol information

PARAMETERS:
    NONE

RETURNS:
{
  "timezone": "UTC",
  "serverTime": 1508631584636,
  "rateLimits": [{
      "rateLimitType": "REQUESTS",
      "interval": "MINUTE",
      "limit": 1200
    },
    {
      "rateLimitType": "ORDERS",
      "interval": "SECOND",
      "limit": 10
    },
    {
      "rateLimitType": "ORDERS",
      "interval": "DAY",
      "limit": 100000
    }
  ],
  "exchangeFilters": [],
  "symbols": [{
    "symbol": "ETHBTC",
    "status": "TRADING",
    "baseAsset": "ETH",
    "baseAssetPrecision": 8,
    "quoteAsset": "BTC",
    "quotePrecision": 8,
    "orderTypes": ["LIMIT", "MARKET"],
    "icebergAllowed": false,
    "filters": [{
      "filterType": "PRICE_FILTER",
      "minPrice": "0.00000100",
      "maxPrice": "100000.00000000",
      "tickSize": "0.00000100"
    }, {
      "filterType": "LOT_SIZE",
      "minQty": "0.00100000",
      "maxQty": "100000.00000000",
      "stepSize": "0.00100000"
    }, {
      "filterType": "MIN_NOTIONAL",
      "minNotional": "0.00100000"
    }]
  }]
}

=cut

sub exchangeInfo {
    return $_[0]->ua->get('/api/v1/ticker/exchangeInfo');
}

=head2 all_prices

my $all_prices = $api->all_prices();

Latest price for all symbols

PARAMETERS:
    NONE

RETURNS:
    An array of HASHrefs:

    [
      {
        "symbol": "LTCBTC",
        "price": "4.00000200"
      },
      {
        "symbol": "ETHBTC",
        "price": "0.07946600"
      }
    ]

    (Source: Binance API documentation)

=cut

sub all_prices {
    return $_[0]->ua->get('/api/v1/ticker/allPrices');
}

=head2 depth

my $depth = $api->depth( symbol => 'ETHBTC' );

PARAMETERS:
- symbol [REQUIRED] Symbol, for example ETHBTC
- limit  [OPTIONAL] Default 100; max 100.

RETURNS:
    A HASHref:

    {
      "lastUpdateId": 1027024,
      "bids": [
        [
          "4.00000000",     // PRICE
          "431.00000000",   // QTY
          []                // Can be ignored
        ]
      ],
      "asks": [
        [
          "4.00000200",
          "12.00000000",
          []
        ]
      ]
    }

    (Source: Binance API documentation)

=cut

sub depth {
    my ($self, %params) = @_;

    unless ($params{'symbol'}) {
        $self->log->error('Parameter "symbol" required');
        Binance::Exception::Parameter::Required->throw(
            error => 'Parameter "symbol" required',
            parameters => ['symbol']
        );
    }

    my $query = {
        symbol => $params{'symbol'},
        limit  => $params{'limit'},
    };

    return $self->ua->get('/api/v1/depth', { query => $query } );
}

=head2 Recent trades list

$api->trades();

Get recent trades (up to last 500).

PARAMETERS:
- symbol           [REQUIRED]
- limit            [OPTIONAL] Default 500; max 500.

RETURNS:
[
  {
    "id": 28457,
    "price": "4.00000100",
    "qty": "12.00000000",
    "time": 1499865549590,
    "isBuyerMaker": true,
    "isBestMatch": true
  }
]

=cut

sub trades {
    my ($self, %params) = @_;

    unless ($params{'symbol'}) {
        $self->log->error('Parameter "symbol" required');
        Binance::Exception::Parameter::Required->throw(
            error => 'Parameter "symbol" required',
            parameters => ['symbol']
        );
    }

    my $query = {
        symbol    => $params{'symbol'},
        limit     => $params{'limit'},
    };

    return $self->ua->get('/api/v1/trades', { query => $query } );
}

=head2 Old trade lookup (MARKET_DATA)

$api->historicalTrades();

Get older trades.

PARAMETERS:
- symbol           [REQUIRED]
- limit            [OPTIONAL] Default 500; max 500.
- fromId           [OPTIONAL] TradeId to fetch from. Default gets most recent trades.

RETURNS:
[
  {
    "id": 28457,
    "price": "4.00000100",
    "qty": "12.00000000",
    "time": 1499865549590,
    "isBuyerMaker": true,
    "isBestMatch": true
  }
]

=cut

sub historicalTrades {
    my ($self, %params) = @_;

    unless ($params{'symbol'}) {
        $self->log->error('Parameter "symbol" required');
        Binance::Exception::Parameter::Required->throw(
            error => 'Parameter "symbol" required',
            parameters => ['symbol']
        );
    }

    my $query = {
        symbol    => $params{'symbol'},
        limit     => $params{'limit'},
        fromId    => $params{'fromId'},
    };

    return $self->ua->get('/api/v1/historicalTrades', { query => $query } );
}

=head2 aggregate_trades

my $aggTrades = $api->aggregate_trades( symbol => 'ETHBTC' );

Gets compressed, aggregate trades. Trades that fill at the time, from the same
order, with the same price will have the quantity aggregated

PARAMETERS:
- symbol    [REQUIRED] Symbol, for example ETHBTC
- fromId    [OPTIONAL] ID to get aggregate trades from INCLUSIVE
- startTime [OPTIONAL] timestamp in ms to get aggregate trades from INCLUSIVE
- endTime   [OPTIONAL] timestamp in ms to get aggregate trades until INCLUSIVE
- limit     [OPTIONAL] Default 500; max 500.

RETURNS:
    An array of HASHrefs:

    [
      {
        "a": 26129,         // Aggregate tradeId
        "p": "0.01633102",  // Price
        "q": "4.70443515",  // Quantity
        "f": 27781,         // First tradeId
        "l": 27781,         // Last tradeId
        "T": 1498793709153, // Timestamp
        "m": true,          // Was the buyer the maker?
        "M": true           // Was the trade the best price match?
      }
    ]

    (Source: Binance API documentation)

=cut

sub aggregate_trades {
    my ($self, %params) = @_;

    unless ($params{'symbol'}) {
        $self->log->error('Parameter "symbol" required');
        Binance::Exception::Parameter::Required->throw(
            error => 'Parameter "symbol" required',
            parameters => ['symbol']
        );
    }

    my $query = {
        symbol    => $params{'symbol'},
        fromId    => $params{'fromId'},
        startTime => $params{'startTime'},
        endTime   => $params{'endTime'},
        limit     => $params{'limit'},
    };

    return $self->ua->get('/api/v1/aggTrades', { query => $query } );
}

=head2 klines

my $klines = $api->klines( symbol => 'ETHBTC', interval => '1M' );

Kline/candlestick bars for a symbol. Klines are uniquely identified by their open
time

PARAMETERS:
- symbol    [REQUIRED] Symbol, for example ETHBTC
- interval  [REQUIRED] ENUM (kline intervals), for example 1m, 1h, 1d or 1M.
- limit     [OPTIONAL] Default 500; max 500.
- startTime [OPTIONAL] timestamp in ms
- endTime   [OPTIONAL] timestamp in ms

RETURNS:
    An array of ARRAYrefs:

    [
      [
        1499040000000,      // Open time
        "0.01634790",       // Open
        "0.80000000",       // High
        "0.01575800",       // Low
        "0.01577100",       // Close
        "148976.11427815",  // Volume
        1499644799999,      // Close time
        "2434.19055334",    // Quote asset volume
        308,                // Number of trades
        "1756.87402397",    // Taker buy base asset volume
        "28.46694368",      // Taker buy quote asset volume
        "17928899.62484339" // Can be ignored
      ]
    ]

    (Source: Binance API documentation)

=cut

sub klines {
    my ($self, %params) = @_;

    unless ($params{'symbol'}) {
        $self->log->error('Parameter "symbol" required');
        Binance::Exception::Parameter::Required->throw(
            error => 'Parameter "symbol" required',
            parameters => ['symbol']
        );
    }

    unless ($params{'interval'}) {
        $self->log->error('Parameter "interval" required');
        Binance::Exception::Parameter::Required->throw(
            error => 'Parameter "interval" required',
            parameters => ['interval']
        );
    }

    my $query = {
        symbol    => $params{'symbol'},
        interval  => $params{'interval'},
        startTime => $params{'startTime'},
        endTime   => $params{'endTime'},
        limit     => $params{'limit'},
    };

    return $self->ua->get('/api/v1/klines', { query => $query } );
}

=head2 ticker

my $ticker = $api->klines( symbol => 'ETHBTC', interval => '1M' );

24 hour price change statistics

PARAMETERS:
- symbol [REQUIRED] Symbol, for example ETHBTC

RETURNS:
    A HASHref:

    {
      "priceChange": "-94.99999800",
      "priceChangePercent": "-95.960",
      "weightedAvgPrice": "0.29628482",
      "prevClosePrice": "0.10002000",
      "lastPrice": "4.00000200",
      "bidPrice": "4.00000000",
      "askPrice": "4.00000200",
      "openPrice": "99.00000000",
      "highPrice": "100.00000000",
      "lowPrice": "0.10000000",
      "volume": "8913.30000000",
      "openTime": 1499783499040,
      "closeTime": 1499869899040,
      "fristId": 28385,   // First tradeId
      "lastId": 28460,    // Last tradeId
      "count": 76         // Trade count
    }

    (Source: Binance API documentation)

=cut

sub ticker {
    my ($self, %params) = @_;

    unless ($params{'symbol'}) {
        $self->log->error('Parameter "symbol" required');
        Binance::Exception::Parameter::Required->throw(
            error => 'Parameter "symbol" required',
            parameters => ['symbol']
        );
    }

    my $query = {
        symbol    => $params{'symbol'},
    };

    return $self->ua->get('/api/v1/ticker/24hr', { query => $query } );
}

=head2 Symbol price ticker

$api->tickerPrice();

Latest price for a symbol or symbols.

PARAMETERS:
- symbol            [OPTIONAL]

RETURNS:
{
  "symbol": "LTCBTC",
  "price": "4.00000200"
}
OR
[
  {
    "symbol": "LTCBTC",
    "price": "4.00000200"
  },
  {
    "symbol": "ETHBTC",
    "price": "0.07946600"
  }
]

=cut

sub tickerPrice {
    my ($self, %params) = @_;

    my $query = {
        symbol    => $params{'symbol'},
    };

    return $self->ua->get('/api/v3/ticker/price', { query => $query } );
}

=head2 all_book_tickers

my $all_book_tickers = $api->all_book_tickers();

Best price/qty on the order book for all symbols

PARAMETERS:
    NONE

RETURNS:
    An array of HASHrefs:

    [
      {
        "symbol": "LTCBTC",
        "bidPrice": "4.00000000",
        "bidQty": "431.00000000",
        "askPrice": "4.00000200",
        "askQty": "9.00000000"
      },
      {
        "symbol": "ETHBTC",
        "bidPrice": "0.07946700",
        "bidQty": "9.00000000",
        "askPrice": "100000.00000000",
        "askQty": "1000.00000000"
      }
    ]

    (Source: Binance API documentation)

=cut

sub all_book_tickers {
    return $_[0]->ua->get('/api/v1/ticker/allBookTickers');
}

=head2 Symbol order book ticker

$api->bookTicker();

Best price/qty on the order book for a symbol or symbols.

PARAMETERS:
- symbol            [OPTIONAL]

RETURNS:
{
  "symbol": "LTCBTC",
  "bidPrice": "4.00000000",
  "bidQty": "431.00000000",
  "askPrice": "4.00000200",
  "askQty": "9.00000000"
}

=cut

sub bookTicker {
    my ($self, %params) = @_;

    my $query = {
        symbol    => $params{'symbol'},
    };

    return $self->ua->get('/api/v1/bookTicker', { query => $query } );
}

=head2 order

my $order = $api->order(
    symbol => 'ETHBTC',
    side   => 'BUY',
    type   => 'LIMIT',
    timeInForce => 'GTC',
    quantity => 1
    price => 0.1
);

Send in a new order

PARAMETERS:
- symbol           [REQUIRED] Symbol, for example ETHBTC
- side             [REQUIRED] BUY or SELL
- type             [REQUIRED] LIMIT or MARKET
- timeInForce      [REQUIRED] GTC or IOC
- quantity         [REQUIRED] Quantity (of symbols) in order
- price            [REQUIRED] Price (of symbol) in order
- newClientOrderId [OPTIONAL] A unique id for the order. Automatically generated
                              if not sent.
- stopPrice        [OPTIONAL] Used with stop orders
- icebergQty       [OPTIONAL] Used with iceberg orders

RETURNS:
    A HASHref:

    {
      "symbol":"LTCBTC",
      "orderId": 1,
      "clientOrderId": "myOrder1" // Will be newClientOrderId
      "transactTime": 1499827319559
    }

    (Source: Binance API documentation)

=cut

sub order {
    my ($self, %params) = @_;

    my @required = ('symbol', 'side', 'type', 'timeInForce', 'quantity', 'price');
    foreach my $param (@required) {
        unless (defined ($params{$param})) {
            $self->log->error('Parameter "'.$param.'" required');
            Binance::Exception::Parameter::Required->throw(
                error => 'Parameter "'.$param.'" required',
                parameters => [$param]
            );
        }
    }

    my $body = {
        symbol           => $params{'symbol'},
        side             => $params{'side'},
        type             => $params{'type'},
        timeInForce      => $params{'timeInForce'},
        quantity         => $params{'quantity'},
        price            => $params{'price'},
        newClientOrderId => $params{'newClientOrderId'},
        stopPrice        => $params{'stopPrice'},
        icebergQty       => $params{'icebergQty'},
    };

    return $self->ua->post('/api/v3/order', { signed => 1, body => $body } );
}

=head2 Test new order (TRADE)

$api->orderTest();

Test new order creation and signature/recvWindow long. Creates and validates a new order but does not send it into the matching engine.

PARAMETERS:
- symbol           [REQUIRED] Symbol, for example ETHBTC
- side             [REQUIRED] BUY or SELL
- type             [REQUIRED] LIMIT or MARKET
- timeInForce      [REQUIRED] GTC or IOC
- quantity         [REQUIRED] Quantity (of symbols) in order
- price            [REQUIRED] Price (of symbol) in order
- newClientOrderId [OPTIONAL] A unique id for the order. Automatically generated
                              if not sent.
- stopPrice        [OPTIONAL] Used with stop orders
- icebergQty       [OPTIONAL] Used with iceberg orders

RETURNS:
{}

=cut

sub orderTest {
    my ($self, %params) = @_;

    my @required = ('symbol', 'side', 'type', 'timeInForce', 'quantity', 'price');
    foreach my $param (@required) {
        unless (defined ($params{$param})) {
            $self->log->error('Parameter "'.$param.'" required');
            Binance::Exception::Parameter::Required->throw(
                error => 'Parameter "'.$param.'" required',
                parameters => [$param]
            );
        }
    }

    my $body = {
        symbol           => $params{'symbol'},
        side             => $params{'side'},
        type             => $params{'type'},
        timeInForce      => $params{'timeInForce'},
        quantity         => $params{'quantity'},
        price            => $params{'price'},
        newClientOrderId => $params{'newClientOrderId'},
        stopPrice        => $params{'stopPrice'},
        icebergQty       => $params{'icebergQty'},
    };

    return $self->ua->post('/api/v3/order/test', { signed => 1, body => $body } );
}

=head2 Cancel order (TRADE)

$api->cancelOrder();

Cancel an active order.

PARAMETERS:
- symbol             [REQUIRED]
- orderId            [OPTIONAL]
- origClientOrderId  [OPTIONAL]
- newClientOrderId   [OPTIONAL] Used to uniquely identify this cancel. Automatically generated by default.
- recvWindow         [OPTIONAL]

RETURNS:
{
  "symbol": "LTCBTC",
  "origClientOrderId": "myOrder1",
  "orderId": 1,
  "clientOrderId": "cancelMyOrder1"
}

=cut

sub cancelOrder {
    my ($self, %params) = @_;

    unless ($params{'symbol'}) {
        $self->log->error('Parameter "symbol" required');
        Binance::Exception::Parameter::Required->throw(
            error => 'Parameter "symbol" required',
            parameters => ['symbol']
        );
    }

    my $body = {
        symbol             => $params{'symbol'},
        orderId            => $params{'orderId'},
        origClientOrderId  => $params{'origClientOrderId'},
        newClientOrderId   => $params{'newClientOrderId'},
        recvWindow         => $params{'recvWindow'},
    };

    return $self->ua->delete('/api/v3/order', { signed => 1, body => $body } );
}

=head2 Current open orders (USER_DATA)

$api->openOrders();

Get all open orders on a symbol. Careful when accessing this with no symbol.

PARAMETERS:
- symbol            [OPTIONAL]
- recvWindow        [OPTIONAL]

RETURNS:
[
  {
    "symbol": "LTCBTC",
    "orderId": 1,
    "clientOrderId": "myOrder1",
    "price": "0.1",
    "origQty": "1.0",
    "executedQty": "0.0",
    "status": "NEW",
    "timeInForce": "GTC",
    "type": "LIMIT",
    "side": "BUY",
    "stopPrice": "0.0",
    "icebergQty": "0.0",
    "time": 1499827319559,
    "isWorking": trueO
  }
]

=cut

sub openOrders {
    my ($self, %params) = @_;

    my $query = {
        symbol     => $params{'symbol'},
        recvWindow => $params{'recvWindow'},
    };
    return $self->ua->get('/api/v3/openOrders', { signed => 1, query => $query } );
}

=head2 All orders (USER_DATA)

$api->allOrders();

Get all account orders; active, canceled, or filled.

PARAMETERS:
- symbol             [REQUIRED]
- orderId            [OPTIONAL]
- limit              [OPTIONAL] Default 500; max 500.
- recvWindow         [OPTIONAL]

RETURNS:
[
  {
    "symbol": "LTCBTC",
    "orderId": 1,
    "clientOrderId": "myOrder1",
    "price": "0.1",
    "origQty": "1.0",
    "executedQty": "0.0",
    "status": "NEW",
    "timeInForce": "GTC",
    "type": "LIMIT",
    "side": "BUY",
    "stopPrice": "0.0",
    "icebergQty": "0.0",
    "time": 1499827319559,
    "isWorking": true
  }
]

=cut

sub allOrders {
    my ($self, %params) = @_;
    unless ($params{'symbol'}) {
        $self->log->error('Parameter "symbol" required');
        Binance::Exception::Parameter::Required->throw(
            error => 'Parameter "symbol" required',
            parameters => ['symbol']
        );
    }
    my $query = {
        symbol     => $params{'symbol'},
        orderId    => $params{'orderId'},
        limit      => $params{'limit'},
        recvWindow => $params{'recvWindow'},
    };
    return $self->ua->get('/api/v3/allOrders', { signed => 1, query => $query } );
}

=head2 Account information (USER_DATA)

$api->account();

Get current account information.

PARAMETERS:
- recvWindow            [OPTIONAL]

RETURNS:
{
  "makerCommission": 15,
  "takerCommission": 15,
  "buyerCommission": 0,
  "sellerCommission": 0,
  "canTrade": true,
  "canWithdraw": true,
  "canDeposit": true,
  "updateTime": 123456789,
  "balances": [
    {
      "asset": "BTC",
      "free": "4723846.89208129",
      "locked": "0.00000000"
    },
    {
      "asset": "LTC",
      "free": "4763368.68006011",
      "locked": "0.00000000"
    }
  ]
}

=cut

sub account {
    my ($self, %params) = @_;

    my $query = {
        recvWindow => $params{'recvWindow'},
    };
    return $self->ua->get('/api/v3/account', { signed => 1, query => $query } );
}

=head2 Account trade list (USER_DATA)

$api->myTrades();

Get trades for a specific account and symbol.

PARAMETERS:
- symbol            [REQUIRED]
- limit             [OPTIONAL] Default 500; max 500.
- fromId            [OPTIONAL] TradeId to fetch from. Default gets most recent trades.
- recvWindow        [OPTIONAL]

RETURNS:
[
  {
    "id": 28457,
    "orderId": 100234,
    "price": "4.00000100",
    "qty": "12.00000000",
    "commission": "10.10000000",
    "commissionAsset": "BNB",
    "time": 1499865549590,
    "isBuyer": true,
    "isMaker": false,
    "isBestMatch": true
  }
]

=cut

sub myTrades {
    my ($self, %params) = @_;
    unless ($params{'symbol'}) {
        $self->log->error('Parameter "symbol" required');
        Binance::Exception::Parameter::Required->throw(
            error => 'Parameter "symbol" required',
            parameters => ['symbol']
        );
    }
    my $query = {
        symbol     => $params{'symbol'},
        limit      => $params{'limit'},
        fromId    => $params{'fromId'},
        recvWindow => $params{'recvWindow'},
    };
    return $self->ua->get('/api/v3/myTrades', { signed => 1, query => $query } );
}

=head2 Start user data stream (USER_STREAM)

$api->startUserDataStream();

Start a new user data stream. The stream will close after 60 minutes unless a keepalive is sent.

PARAMETERS:
       NONE

RETURNS:
{
  "listenKey": "pqia91ma19a5s61cv6a81va65sdf19v8a65a1a5s61cv6a81va65sdf19v8a65a1"
}

=cut

sub startUserDataStream {
    return $_[0]->ua->post('/api/v1/ticker/userDataStream');
}

=head2 Keepalive user data stream (USER_STREAM)

$api->keepAliveuserDataStream();

Keepalive a user data stream to prevent a time out. User data streams will close after 60 minutes. It's recommended to send a ping about every 30 minutes.

PARAMETERS:
- listenKey          [REQUIRED]

RETURNS:
{}

=cut

sub keepAliveuserDataStream {
    my ($self, %params) = @_;
    unless ($params{'listenKey'}) {
        $self->log->error('Parameter "listenKey" required');
        Binance::Exception::Parameter::Required->throw(
            error => 'Parameter "listenKey" required',
            parameters => ['listenKey']
        );
    }
    my $query = {
        listenKey  => $params{'listenKey'},
    };
    return $self->ua->put('/api/v1/userDataStream', { query => $query } );
}

=head2 Close user data stream (USER_STREAM)

$api->deleteUserDataStream();

Close out a user data stream.

PARAMETERS:
- listenKey          [REQUIRED]

RETURNS:
{}

=cut

sub deleteUserDataStream {
    my ($self, %params) = @_;
    unless ($params{'listenKey'}) {
        $self->log->error('Parameter "listenKey" required');
        Binance::Exception::Parameter::Required->throw(
            error => 'Parameter "listenKey" required',
            parameters => ['listenKey']
        );
    }
    my $query = {
        listenKey  => $params{'listenKey'},
    };
    return $self->ua->delete('/api/v1/userDataStream', { query => $query } );
}


sub log { return $_[0]->{logger}; }
sub ua  { return $_[0]->{ua}; }

1;
