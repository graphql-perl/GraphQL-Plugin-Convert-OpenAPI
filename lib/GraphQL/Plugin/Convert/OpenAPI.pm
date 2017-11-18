package GraphQL::Plugin::Convert::OpenAPI;
use 5.008001;
use strict;
use warnings;
use GraphQL::Schema;
use GraphQL::Debug qw(_debug);
use JSON::Validator::OpenAPI;

our $VERSION = "0.03";
use constant DEBUG => $ENV{GRAPHQL_DEBUG};
my $validator = JSON::Validator::OpenAPI->new; # singleton

my %TYPEMAP = (
  string => 'String',
  date => 'DateTime',
  integer => 'Int',
  number => 'Float',
  boolean => 'Boolean',
);
my %TYPE2SCALAR = map { ($_ => 1) } qw(ID String Int Float Boolean);

sub _apply_modifier {
  my ($modifier, $typespec) = @_;
  return $typespec if !$modifier;
  return $typespec if $modifier eq 'non_null'
    and ref $typespec eq 'ARRAY'
    and $typespec->[0] eq 'non_null'; # no double-non_null
  [ $modifier, { type => $typespec } ];
}

sub _remove_modifiers {
  my ($typespec) = @_;
  return $typespec->{type} if ref $typespec eq 'HASH';
  return $typespec if ref $typespec ne 'ARRAY';
  _remove_modifiers($typespec->[1]);
}

sub _type2createinput {
  my ($name, $fields, $name2pk21, $fk21, $prop21, $name2type) = @_;
  +{
    kind => 'input',
    name => "${name}CreateInput",
    fields => {
      (map { ($_ => $fields->{$_}) }
        grep !$name2pk21->{$name}{$_} && !$fk21->{$_}, keys %$prop21),
      _make_fk_fields($name, $fk21, $name2type, $name2pk21),
    },
  };
}

sub _type2searchinput {
  my ($name, $prop2rawtype, $name2pk21, $prop21, $name2type) = @_;
  +{
    kind => 'input',
    name => "${name}SearchInput",
    fields => {
      (map { ($_ => { type => $prop2rawtype->{$_} }) }
        grep !$name2pk21->{$name}{$_}, keys %$prop21),
    },
  };
}

sub _type2mutateinput {
  my ($name, $prop2rawtype, $fields, $name2pk21, $prop21) = @_;
  +{
    kind => 'input',
    name => "${name}MutateInput",
    fields => {
      (map { ($_ => { type => $prop2rawtype->{$_} }) }
        grep !$name2pk21->{$name}{$_}, keys %$prop21),
      (map { ($_ => $fields->{$_}) }
        grep $name2pk21->{$name}{$_}, keys %$prop21),
    },
  };
}

sub _make_fk_fields {
  my ($name, $fk21, $name2type, $name2pk21) = @_;
  my $type = $name2type->{$name};
  (map {
    my $field_type = $type->{fields}{$_}{type};
    if (!$TYPE2SCALAR{_remove_modifiers($field_type)}) {
      my $non_null =
        ref($field_type) eq 'ARRAY' && $field_type->[0] eq 'non_null';
      $field_type = _apply_modifier(
        $non_null && 'non_null', _remove_modifiers($field_type)."MutateInput"
      );
    }
    ($_ => { type => $field_type })
  } keys %$fk21);
}

sub field_resolver {
  my ($root_value, $args, $context, $info) = @_;
  my $field_name = $info->{field_name};
  DEBUG and _debug('OpenAPI.resolver', $root_value, $field_name, $args);
  my $property = ref($root_value) eq 'HASH'
    ? $root_value->{$field_name}
    : $root_value;
  return $property->($args, $context, $info) if ref $property eq 'CODE';
  return $property // die "OpenAPI.resolver could not resolve '$field_name'\n"
    if ref $root_value eq 'HASH' or !$root_value->can($field_name);
  return $root_value->$field_name($args, $context, $info)
    if !UNIVERSAL::isa($root_value, 'DBIx::Class::Core');
  # dbic search
  my $rs = $root_value->$field_name;
  $rs = [ $rs->all ] if $info->{return_type}->isa('GraphQL::Type::List');
  return $rs;
}

sub _subfieldrels {
  my ($name, $name2rel21, $field_nodes) = @_;
  grep $name2rel21->{$name}->{$_},
    map $_->{name}, grep $_->{kind} eq 'field', map @{$_->{selections}},
    grep $_->{kind} eq 'field', @$field_nodes;
}

sub _make_update_arg {
  my ($name, $pk21, $input) = @_;
  +{ map { $_ => $input->{$_} } grep !$pk21->{$_}, keys %$input };
}

sub _trim_name {
  my ($name) = @_;
  $name =~ s#[^a-zA-Z0-9_]##g;
  $name;
}

sub _get_type {
  my ($info, $maybe_name, $name2type, $name2prop2rawtype, $name2fk21, $name2prop21) = @_;
  DEBUG and _debug("_get_type($maybe_name)", $info);
  return 'String' if !%$info; # bodge but unavoidable
  if ($info->{'$ref'}) {
    DEBUG and _debug("_get_type($maybe_name) ref");
    my $rawtype = $info->{'$ref'};
    $rawtype =~ s:^#/definitions/::;
    return $rawtype;
  }
  if ($info->{additionalProperties}) {
    DEBUG and _debug("_get_type($maybe_name) aP");
    return _get_type(
      {
        type => 'array',
        items => {
          type => 'object',
          properties => {
            key => { type => 'string' },
            value => $info->{additionalProperties},
          },
        },
      },
      $maybe_name,
      $name2type, $name2prop2rawtype, $name2fk21, $name2prop21,
    );
  }
  if ($info->{properties}) {
    DEBUG and _debug("_get_type($maybe_name) p");
    return _get_spec_from_info(
      $maybe_name, $info,
      $name2type, $name2prop2rawtype, $name2fk21, $name2prop21,
    );
  }
  if ($info->{type} eq 'array') {
    DEBUG and _debug("_get_type($maybe_name) a");
    return _apply_modifier(
      'list',
      _get_type(
        $info->{items}, $maybe_name,
        $name2type, $name2prop2rawtype, $name2fk21, $name2prop21,
      )
    );
  }
  DEBUG and _debug("_get_type($maybe_name) simple");
  $TYPEMAP{$info->{type}}
    // die "'$maybe_name' unknown data type: @{[$info->{type}]}\n";
}

sub _refinfo2fields {
  my ($name, $refinfo, $name2type, $name2prop2rawtype, $name2fk21, $name2prop21) = @_;
  my %fields;
  my $properties = $refinfo->{properties};
  my %required = map { ($_ => 1) } @{$refinfo->{required}};
  for my $prop (keys %$properties) {
    my $info = $properties->{$prop};
    DEBUG and _debug("_refinfo2fields($name) $prop", $info);
    my $rawtype = _get_type(
      $info, $name.ucfirst($prop),
      $name2type, $name2prop2rawtype, $name2fk21, $name2prop21,
    );
    $name2prop2rawtype->{$name}{$prop} = $rawtype;
    my $fulltype = _apply_modifier(
      $required{$prop} && 'non_null',
      $rawtype,
    );
    $fields{$prop} = +{ type => $fulltype };
    $fields{$prop}->{description} = $info->{description}
      if $info->{description};
    $name2fk21->{$name}{$prop} = 1 if $info->{is_foreign_key};
    $name2prop21->{$name}{$prop} = 1;
  }
  \%fields;
}

sub _get_spec_from_info {
  my (
    $name, $refinfo,
    $name2type, $name2prop2rawtype, $name2fk21, $name2prop21,
  ) = @_;
  DEBUG and _debug("_get_spec_from_info($name)", $refinfo);
  my $fields = _refinfo2fields(
    $name, $refinfo,
    $name2type, $name2prop2rawtype, $name2fk21, $name2prop21,
  );
  my $spec = +{
    kind => $refinfo->{discriminator} ? 'interface' : 'type',
    name => $name,
    fields => $fields,
  };
  $spec->{description} = $refinfo->{title} if $refinfo->{title};
  $spec->{description} = $refinfo->{description}
    if $refinfo->{description};
  $name2type->{$name} = $spec;
  $name;
}

sub to_graphql {
  my ($class, $spec) = @_;
  my $dbic_schema_cb = undef;
  my $openapi_schema = $validator->schema($spec)->schema;
  my $defs = $openapi_schema->get("/definitions");
  my %root_value;
  my @ast;
  my (
    %name2type, %name2prop21, %name2pk21, %name2fk21, %name2rel21,
    %name2prop2rawtype,
  );
  for my $name (keys %$defs) {
    _get_spec_from_info(
      _trim_name($name), $defs->{$name},
      \%name2type, \%name2prop2rawtype, \%name2fk21, \%name2prop21,
    );
  }
  push @ast, values %name2type;
#  push @ast, map _type2createinput(
#    $_, $name2type{$_}->{fields}, \%name2pk21, $name2fk21{$_},
#    $name2prop21{$_}, \%name2type,
#  ), keys %name2type;
#  push @ast, map _type2searchinput(
#    $_, $name2prop2rawtype{$_}, \%name2pk21,
#    $name2prop21{$_}, \%name2type,
#  ), keys %name2type;
#  push @ast, map _type2mutateinput(
#    $_, $name2prop2rawtype{$_}, $name2type{$_}->{fields}, \%name2pk21,
#    $name2prop21{$_},
#  ), keys %name2type;
  push @ast, {
    kind => 'type',
    name => 'Query',
    fields => {
      map {
        my $name = $_;
        my $type = $name2type{$name};
        my $pksearch_name = lcfirst $name;
        my $input_search_name = "search$name";
        # TODO now only one deep, no handle fragments or abstract types
        $root_value{$pksearch_name} = sub {
          my ($args, $context, $info) = @_;
          my @subfieldrels = _subfieldrels($name, \%name2rel21, $info->{field_nodes});
          DEBUG and _debug('OpenAPI.root_value', @subfieldrels);
          [
            $dbic_schema_cb->()->resultset($name)->search(
              +{ map { ("me.$_" => $args->{$_}) } keys %$args },
              {
                prefetch => \@subfieldrels,
              },
            )
          ];
        };
#        $root_value{$input_search_name} = sub {
#          my ($args, $context, $info) = @_;
#          my @subfieldrels = _subfieldrels($name, \%name2rel21, $info->{field_nodes});
#          DEBUG and _debug('OpenAPI.root_value', @subfieldrels);
#          [
#            $dbic_schema_cb->()->resultset($name)->search(
#              +{
#                map { ("me.$_" => $args->{input}{$_}) } keys %{$args->{input}}
#              },
#              {
#                prefetch => \@subfieldrels,
#              },
#            )
#          ];
#        };
        (
          # the PKs query
          $pksearch_name => {
            type => _apply_modifier('list', $name),
            args => {
              map {
                $_ => {
                  type => _apply_modifier('non_null', _apply_modifier('list',
                    _apply_modifier('non_null', $type->{fields}{$_}{type})
                  ))
                }
              } keys %{ $name2pk21{$name} }
            },
          },
#          $input_search_name => {
#            description => 'input to search',
#            type => _apply_modifier('list', $name),
#            args => {
#              input => {
#                type => _apply_modifier('non_null', "${name}SearchInput")
#              },
#            },
#          },
        )
      } keys %name2type
    },
  };
#  push @ast, {
#    kind => 'type',
#    name => 'Mutation',
#    fields => {
#      map {
#        my $name = $_;
#        my $type = $name2type{$name};
#        my $create_name = "create$name";
#        $root_value{$create_name} = sub {
#          my ($args, $context, $info) = @_;
#          my @subfieldrels = _subfieldrels($name, \%name2rel21, $info->{field_nodes});
#          DEBUG and _debug("OpenAPI.root_value($create_name)", $args, \@subfieldrels);
#          [
#            map $dbic_schema_cb->()->resultset($name)->create(
#              $_,
#              {
#                prefetch => \@subfieldrels,
#              },
#            ), @{ $args->{input} }
#          ];
#        };
#        my $update_name = "update$name";
#        $root_value{$update_name} = sub {
#          my ($args, $context, $info) = @_;
#          my @subfieldrels = _subfieldrels($name, \%name2rel21, $info->{field_nodes});
#          DEBUG and _debug("OpenAPI.root_value($update_name)", $args, \@subfieldrels);
#          [
#            map {
#              my $input = $_;
#              my $row = $dbic_schema_cb->()->resultset($name)->find(
#                +{
#                  map {
#                    my $key = $_;
#                    ("me.$key" => $input->{$key})
#                  } keys %{$name2pk21{$name}}
#                },
#                {
#                  prefetch => \@subfieldrels,
#                },
#              );
#              $row
#                ? $row->update(
#                  _make_update_arg($name, $name2pk21{$name}, $input)
#                )->discard_changes
#                : GraphQL::Error->coerce("$name not found");
#            } @{ $args->{input} }
#          ];
#        };
#        my $delete_name = "delete$name";
#        $root_value{$delete_name} = sub {
#          my ($args, $context, $info) = @_;
#          DEBUG and _debug("OpenAPI.root_value($delete_name)", $args);
#          [
#            map {
#              my $input = $_;
#              my $row = $dbic_schema_cb->()->resultset($name)->find(
#                +{
#                  map {
#                    my $key = $_;
#                    ("me.$key" => $input->{$key})
#                  } keys %{$name2pk21{$name}}
#                },
#              );
#              $row
#                ? $row->delete && 1
#                : GraphQL::Error->coerce("$name not found");
#            } @{ $args->{input} }
#          ];
#        };
#        (
#          $create_name => {
#            type => _apply_modifier('list', $name),
#            args => {
#              input => { type => _apply_modifier('non_null',
#                _apply_modifier('list',
#                  _apply_modifier('non_null', "${name}CreateInput")
#                )
#              ) },
#            },
#          },
#          $update_name => {
#            type => _apply_modifier('list', $name),
#            args => {
#              input => { type => _apply_modifier('non_null',
#                _apply_modifier('list',
#                  _apply_modifier('non_null', "${name}MutateInput")
#                )
#              ) },
#            },
#          },
#          $delete_name => {
#            type => _apply_modifier('list', 'Boolean'),
#            args => {
#              input => { type => _apply_modifier('non_null',
#                _apply_modifier('list',
#                  _apply_modifier('non_null', "${name}MutateInput")
#                )
#              ) },
#            },
#          },
#        )
#      } keys %name2type
#    },
#  };
  +{
    schema => GraphQL::Schema->from_ast(\@ast),
    root_value => \%root_value,
    resolver => \&field_resolver,
  };
}

=encoding utf-8

=head1 NAME

GraphQL::Plugin::Convert::OpenAPI - convert OpenAPI schema to GraphQL schema

=begin markdown

# PROJECT STATUS

| OS      |  Build status |
|:-------:|--------------:|
| Linux   | [![Build Status](https://travis-ci.org/graphql-perl/GraphQL-Plugin-Convert-OpenAPI.svg?branch=master)](https://travis-ci.org/graphql-perl/GraphQL-Plugin-Convert-OpenAPI) |

[![CPAN version](https://badge.fury.io/pl/GraphQL-Plugin-Convert-OpenAPI.svg)](https://metacpan.org/pod/GraphQL::Plugin::Convert::OpenAPI)

=end markdown

=head1 SYNOPSIS

  use GraphQL::Plugin::Convert::OpenAPI;
  use Schema;
  my $converted = GraphQL::Plugin::Convert::OpenAPI->to_graphql(
    sub { Schema->connect }
  );
  print $converted->{schema}->to_doc;

=head1 DESCRIPTION

This module implements the L<GraphQL::Plugin::Convert> API to convert
a L<JSON::Validator::OpenAPI> to L<GraphQL::Schema> etc.

=head2 Example

Consider this minimal data model:

  blog:
    id # primary key
    articles # has_many
    title # non null
    language # nullable
  article:
    id # primary key
    blog # foreign key to Blog
    title # non null
    content # nullable

=head2 Generated Output Types

These L<GraphQL::Type::Object> types will be generated:

  type Blog {
    id: Int!
    articles: [Article]
    title: String!
    language: String
  }

  type Article {
    id: Int!
    blog: Blog
    title: String!
    content: String
  }

  type Query {
    blog(id: [Int!]!): [Blog]
    article(id: [Int!]!): [Blog]
  }

Note that while the queries take a list, the return order is
undefined. This also applies to the mutations. If this matters, request
the primary key fields and use those to sort.

=head2 Generated Input Types

Different input types are needed for each of CRUD (Create, Read, Update,
Delete).

The create one needs to have non-null fields be non-null, for idiomatic
GraphQL-level error-catching. The read one needs all fields nullable,
since this will be how searches are implemented, allowing fields to be
left un-searched-for. Both need to omit primary key fields. The read
one also needs to omit foreign key fields, since the idiomatic GraphQL
way for this is to request the other object, with this as a field on it,
then request any required fields of this.

Meanwhile, the update and delete ones need to include the primary key
fields, to indicate what to mutate, and also all non-primary key fields
as nullable, which for update will mean leaving them unchanged, and for
delete is to be ignored.

Therefore, for the above, these input types (and an updated Query,
and Mutation) are created:

  input BlogCreateInput {
    title: String!
    language: String
  }

  input BlogSearchInput {
    title: String
    language: String
  }

  input BlogMutateInput {
    id: Int!
    title: String
    language: String
  }

  input ArticleCreateInput {
    blog_id: Int!
    title: String!
    content: String
  }

  input ArticleSearchInput {
    title: String
    content: String
  }

  input ArticleMutateInput {
    id: Int!
    title: String!
    language: String
  }

  type Mutation {
    createBlog(input: [BlogCreateInput!]!): [Blog]
    createArticle(input: [ArticleCreateInput!]!): [Article]
    deleteBlog(input: [BlogMutateInput!]!): [Boolean]
    deleteArticle(input: [ArticleMutateInput!]!): [Boolean]
    updateBlog(input: [BlogMutateInput!]!): [Blog]
    updateArticle(input: [ArticleMutateInput!]!): [Article]
  }

  extends type Query {
    searchBlog(input: BlogSearchInput!): [Blog]
    searchArticle(input: ArticleSearchInput!): [Article]
  }

=head1 ARGUMENTS

To the C<to_graphql> method: a code-ref returning a L<DBIx::Class::Schema>
object. This is so it can be called during the conversion process,
but also during execution of a long-running process to e.g. execute
database queries, when the database handle passed to this method as a
simple value might have expired.

=head1 PACKAGE FUNCTIONS

=head2 field_resolver

This is available as C<\&GraphQL::Plugin::Convert::OpenAPI::field_resolver>
in case it is wanted for use outside of the "bundle" of the C<to_graphql>
method.

=head1 DEBUGGING

To debug, set environment variable C<GRAPHQL_DEBUG> to a true value.

=head1 AUTHOR

Ed J, C<< <etj at cpan.org> >>

Parts based on L<https://github.com/yarax/swagger-to-graphql>

=head1 LICENSE

Copyright (C) Ed J

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
