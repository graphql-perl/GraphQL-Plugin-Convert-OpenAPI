use strict;
use Test::More 0.98;

use_ok 'GraphQL::Plugin::Convert::OpenAPI';

my $expected = join '', <DATA>;
my $converted = GraphQL::Plugin::Convert::OpenAPI->to_graphql(
  't/cpantesters-v3.json'
);
my $got = $converted->{schema}->to_doc;
#open my $fh, '>', 'tf'; print $fh $got; # uncomment to regenerate
is $got, $expected;

done_testing;

__DATA__
type AcceptedReports {
  id: String!
  status: String
}

type Distribution {
  name: String!
  # A list of prerequisites
  prerequisites: [Prerequisite]
  version: String!
}

type Environment {
  language: Language!
  system: System!
  toolchain: [EnvironmentToolchain]
  user_agent: String
}

type EnvironmentToolchain {
  key: String
  value: String
}

# OpenAPI Error Object
type Error {
  errors: [ErrorErrors]
}

type ErrorErrors {
  # Human readable description of the error
  message: String!
  # JSON pointer to the input data where the error occur
  path: String
}

# The report grade. Pass is passing tests. Fail is failing tests. NA is the distribution cannot be used on the system. Unknown is any other problem.
enum Grade {
  fail
  na
  pass
  unknown
}

interface Language {
  archname: String!
  build: String
  name: LanguageName!
  variables: [LanguageVariables]
  version: String!
}

enum LanguageName {
  Perl5
  Perl6
}

type LanguageVariables {
  key: String
  value: String
}

type NewReport {
  comments: String
  distribution: Distribution!
  environment: Environment!
  reporter: Reporter!
  result: Result!
}

# Language data for Perl 5 reports
type Perl5 implements Language {
  archname: String!
  build: String
  commit_id: String
  name: LanguageName!
  variables: [LanguageVariables]
  version: String
}

# Language data for Perl 6 reports
type Perl6 implements Language {
  archname: String!
  backend: Perl6Backend
  build: String
  implementation: String
  name: LanguageName!
  variables: [LanguageVariables]
  version: String!
}

type Perl6Backend {
  engine: String
  version: String
}

type Prerequisite {
  have: String
  name: String!
  need: String!
  phase: String!
}

type Query {
  acceptedReports: [AcceptedReports]
  distribution: [Distribution]
  environment: [Environment]
  environmentToolchain: [EnvironmentToolchain]
  error: [Error]
  errorErrors: [ErrorErrors]
  grade: [Grade]
  language: [Language]
  languageName: [LanguageName]
  languageVariables: [LanguageVariables]
  newReport: [NewReport]
  perl5: [Perl5]
  perl6: [Perl6]
  perl6Backend: [Perl6Backend]
  prerequisite: [Prerequisite]
  release: [Release]
  report: [Report]
  reportSummary: [ReportSummary]
  reporter: [Reporter]
  result: [Result]
  resultTodo: [ResultTodo]
  system: [System]
  systemVariables: [SystemVariables]
  testOutput: [TestOutput]
  upload: [Upload]
}

# A summary of test reports for a single CPAN release
type Release {
  # The CPAN ID of the author who released this version of this distribution
  author: String
  # The distribution name
  dist: String
  # The number of test failures for this release
  fail: Int
  # The number of NA results for this release, which means the release does not apply to the tester's machine due to OS, Perl version, or other conditions
  na: Int
  # The number of test passes for this release
  pass: Int
  # The number of unknown reports for this release
  unknown: Int
  # The distribution release version
  version: String
}

# CPAN Testers report
type Report {
  comments: String
  created: String
  distribution: Distribution!
  environment: Environment!
  id: String!
  reporter: Reporter!
  result: Result!
}

# Flattened summary data from the test report data structure
type ReportSummary {
  # The date/time of the report in ISO8601 format
  date: String
  # The name of the distribution tested
  dist: String
  grade: Grade
  # The GUID of the full report this data came from
  guid: String
  # The name of the operating system, like 'linux', 'MSWin32', 'darwin'
  osname: String
  # The version of the operating system, like '4.8.0-2-amd64'
  osvers: String
  # The Perl version that ran the tests, like '5.24.0'
  perl: String
  # The Perl platform that ran the tests, like 'x86_64-linux'
  platform: String
  # The name/email of the reporter who submitted this report
  reporter: String
  # The version of the distribution tested
  version: String
}

type Reporter {
  email: String!
  name: String
}

type Result {
  duration: Int
  failures: Int
  grade: Grade!
  output: TestOutput!
  skipped: Int
  tests: Int
  todo: ResultTodo
  warnings: Int
}

type ResultTodo {
  fail: Int!
  pass: Int!
}

type System {
  cpu_count: String
  cpu_description: String
  cpu_type: String
  filesystem: String
  hostname: String
  osname: String!
  osversion: String
  variables: [SystemVariables]
}

type SystemVariables {
  key: String
  value: String
}

# At least one of the properties must be set
type TestOutput {
  build: String
  configure: String
  install: String
  test: String
  uncategorized: String
}

# A release to CPAN
type Upload {
  # The CPAN ID of the author who released this version of this distribution
  author: String
  # The distribution name
  dist: String
  # The filename on PAUSE, without the author directory
  filename: String
  # The date/time the file was released to CPAN, in UTC
  released: String
  # The distribution release version
  version: String
}
