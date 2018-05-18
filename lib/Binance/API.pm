package Binance::API;

# MIT License
#
# Copyright (c) 2017 Lari Taskula  <lari@taskula.fi>
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

=head2 time

$api->ping();

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

sub log { return $_[0]->{logger}; }
sub ua  { return $_[0]->{ua}; }

1;