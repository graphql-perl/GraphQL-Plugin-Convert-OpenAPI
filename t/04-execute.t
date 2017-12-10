use strict;
use Test::More 0.98;
use File::Spec;
use GraphQL::Execution qw(execute);
use Data::Dumper;
use JSON::MaybeXS;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE};

use_ok 'GraphQL::Plugin::Convert::OpenAPI';

sub run_test {
  my ($args, $expected) = @_;
  my $got = execute(@$args);
  #open my $fh, '>', 'tf'; print $fh nice_dump($got); # uncomment to regenerate
  is_deeply $got, $expected or diag nice_dump($got);
}

sub nice_dump {
  my ($got) = @_;
  local ($Data::Dumper::Sortkeys, $Data::Dumper::Indent, $Data::Dumper::Terse);
  $Data::Dumper::Sortkeys = $Data::Dumper::Indent = $Data::Dumper::Terse = 1;
  Dumper $got;
}

my $converted = GraphQL::Plugin::Convert::OpenAPI->to_graphql(
  't/04-corpus.json'
);
my $expected = eval join '', <DATA>;

my $doc = <<'EOF';
{
  getInventory {
    key
    value
  }
}
EOF
run_test(
  [
    $converted->{schema}, $doc, $converted->{root_value},
    (undef) x 3, $converted->{resolver},
  ],
  $expected,
);

done_testing;

__DATA__
{
  'data' => {
    'getInventory' => [
      {
        'key' => '$status',
        'value' => 9
      },
      {
        'key' => '111',
        'value' => 1
      },
      {
        'key' => '12122112',
        'value' => 1
      },
      {
        'key' => '123',
        'value' => 3
      },
      {
        'key' => '2',
        'value' => 1
      },
      {
        'key' => '200',
        'value' => 4
      },
      {
        'key' => 'AVAILABLE',
        'value' => 2
      },
      {
        'key' => 'Available',
        'value' => 3
      },
      {
        'key' => 'Availible',
        'value' => 1
      },
      {
        'key' => 'Beetje gek',
        'value' => 4
      },
      {
        'key' => 'Currently unavailable',
        'value' => 1
      },
      {
        'key' => 'Duis veli',
        'value' => 1
      },
      {
        'key' => 'Hairy Monster',
        'value' => 4
      },
      {
        'key' => 'Healthy',
        'value' => 1
      },
      {
        'key' => 'InProgress',
        'value' => 1
      },
      {
        'key' => 'Lorem do',
        'value' => 1
      },
      {
        'key' => 'NA',
        'value' => 1
      },
      {
        'key' => 'NOT available',
        'value' => 2
      },
      {
        'key' => 'NOt available',
        'value' => 6
      },
      {
        'key' => 'Not-Operated',
        'value' => 10
      },
      {
        'key' => 'Offline',
        'value' => 3
      },
      {
        'key' => 'Operated',
        'value' => 3
      },
      {
        'key' => 'Pend',
        'value' => 1
      },
      {
        'key' => 'Puppy',
        'value' => 2
      },
      {
        'key' => 'Rishna',
        'value' => 1
      },
      {
        'key' => 'Single',
        'value' => 1
      },
      {
        'key' => 'Sol',
        'value' => 1
      },
      {
        'key' => 'Sold',
        'value' => 4
      },
      {
        'key' => 'Testing Status',
        'value' => 1
      },
      {
        'key' => 'TestingStatus"}',
        'value' => 1
      },
      {
        'key' => 'a',
        'value' => 1
      },
      {
        'key' => 'aahe jivant',
        'value' => 1
      },
      {
        'key' => 'ad commodo no',
        'value' => 1
      },
      {
        'key' => 'aliqu',
        'value' => 1
      },
      {
        'key' => 'alive',
        'value' => 4
      },
      {
        'key' => 'asdasd',
        'value' => 1
      },
      {
        'key' => 'asdf',
        'value' => 1
      },
      {
        'key' => 'autereprehe',
        'value' => 1
      },
      {
        'key' => 'avaijhlable',
        'value' => 2
      },
      {
        'key' => 'availabe',
        'value' => 1
      },
      {
        'key' => 'availabel',
        'value' => 1
      },
      {
        'key' => 'availabl',
        'value' => 2
      },
      {
        'key' => 'available',
        'value' => 10698
      },
      {
        'key' => 'available-now!',
        'value' => 1
      },
      {
        'key' => 'available2',
        'value' => 1
      },
      {
        'key' => 'available;pending;sold',
        'value' => 1
      },
      {
        'key' => 'availableX',
        'value' => 8
      },
      {
        'key' => 'availableXYZ',
        'value' => 3
      },
      {
        'key' => 'availableeeee',
        'value' => 1
      },
      {
        'key' => 'avaliable',
        'value' => 1
      },
      {
        'key' => 'avc',
        'value' => 1
      },
      {
        'key' => 'beetje gekkig',
        'value' => 1
      },
      {
        'key' => 'beschikbaar',
        'value' => 1
      },
      {
        'key' => 'booked',
        'value' => 5
      },
      {
        'key' => 'changing',
        'value' => 1
      },
      {
        'key' => 'clear',
        'value' => 1
      },
      {
        'key' => 'consectetur nis',
        'value' => 1
      },
      {
        'key' => 'cupidatat culpa a',
        'value' => 1
      },
      {
        'key' => 'dead',
        'value' => 1
      },
      {
        'key' => 'deseru',
        'value' => 1
      },
      {
        'key' => 'dfdd',
        'value' => 1
      },
      {
        'key' => 'disponible',
        'value' => 2
      },
      {
        'key' => 'do aliquip',
        'value' => 1
      },
      {
        'key' => 'do ex',
        'value' => 1
      },
      {
        'key' => 'dolor Duis se',
        'value' => 1
      },
      {
        'key' => 'dolor dolore ut',
        'value' => 1
      },
      {
        'key' => 'don\'tknw',
        'value' => 4
      },
      {
        'key' => 'estsit mol',
        'value' => 1
      },
      {
        'key' => 'foo',
        'value' => 1
      },
      {
        'key' => 'fugiat est of',
        'value' => 1
      },
      {
        'key' => 'gadse',
        'value' => 1
      },
      {
        'key' => 'good',
        'value' => 1
      },
      {
        'key' => 'happy',
        'value' => 2
      },
      {
        'key' => 'hello and hai',
        'value' => 1
      },
      {
        'key' => 'in nostrud amet mollit',
        'value' => 1
      },
      {
        'key' => 'ipsum pariatur et',
        'value' => 1
      },
      {
        'key' => 'ipsum re',
        'value' => 1
      },
      {
        'key' => 'irure ',
        'value' => 1
      },
      {
        'key' => 'lkhl',
        'value' => 5
      },
      {
        'key' => 'locha',
        'value' => 1
      },
      {
        'key' => 'mollit mi',
        'value' => 1
      },
      {
        'key' => 'nah',
        'value' => 2
      },
      {
        'key' => 'nimalum',
        'value' => 1
      },
      {
        'key' => 'nonexistent',
        'value' => 2
      },
      {
        'key' => 'nostrud tempor ad quis pr',
        'value' => 1
      },
      {
        'key' => 'not available',
        'value' => 10
      },
      {
        'key' => 'notavailable',
        'value' => 1
      },
      {
        'key' => 'pending',
        'value' => 325
      },
      {
        'key' => 'placed',
        'value' => 25
      },
      {
        'key' => 'purchased',
        'value' => 1
      },
      {
        'key' => 'quiid adi',
        'value' => 1
      },
      {
        'key' => 'quis est',
        'value' => 1
      },
      {
        'key' => 'reprehender',
        'value' => 1
      },
      {
        'key' => 'reserved',
        'value' => 3
      },
      {
        'key' => 's',
        'value' => 1
      },
      {
        'key' => 'sick',
        'value' => 1
      },
      {
        'key' => 'sint Ex',
        'value' => 1
      },
      {
        'key' => 'sint dolore in',
        'value' => 1
      },
      {
        'key' => 'sleeping',
        'value' => 14
      },
      {
        'key' => 'sol',
        'value' => 3
      },
      {
        'key' => 'sold',
        'value' => 363
      },
      {
        'key' => 'sold out',
        'value' => 2
      },
      {
        'key' => 'soldffff',
        'value' => 1
      },
      {
        'key' => 'solfffdgd',
        'value' => 1
      },
      {
        'key' => 'spoken for',
        'value' => 1
      },
      {
        'key' => 'status',
        'value' => 104
      },
      {
        'key' => 'string',
        'value' => 77371
      },
      {
        'key' => 'test',
        'value' => 2
      },
      {
        'key' => 'unauthorized',
        'value' => 1
      },
      {
        'key' => 'unavailable',
        'value' => 1
      },
      {
        'key' => 'used for test by awaituv',
        'value' => 1
      },
      {
        'key' => 'ut occae',
        'value' => 1
      },
      {
        'key' => 'velit',
        'value' => 1
      },
      {
        'key' => 'voluptate non d',
        'value' => 1
      },
      {
        'key' => 'waiting',
        'value' => 1
      },
      {
        'key' => 'wwww',
        'value' => 3
      },
      {
        'key' => "\x{88c5}\x{903c}\x{4e2d}",
        'value' => 1
      }
    ]
  }
}
