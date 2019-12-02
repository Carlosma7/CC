#!/usr/bin/env perl

use strict;
use warnings;
use v5.14;
use Git::Hooks;
use File::Slurp qw(read_file write_file);

my $layout_preffix=<<EOT;
---
layout: index

EOT

POST_COMMIT {
  my ($git) = @_;
  my $branch =  run_command($git, qw/rev-parse --abbrev-ref HEAD/);
  if ( $branch =~ /master/ ) {
    my $commit_msg = run_command($git, qw/log -1 --pretty=%B/ );
    my $changed = run_command($git, qw/show --name-status/);
    say "Changed $changed";
    my @changed_files = ($changed =~ /\s\w\s+(\S+)/g);
    my @mds = grep ( /\.md/, @changed_files );
    #Now change branch and process
    #Inspired by http://stackoverflow.com/questions/15214762/how-can-i-sync-documentation-with-github-pages
    $git->command(qw/checkout gh-pages/);
    for my $f ( @mds ) {
      $git->command( 'checkout', 'master', '--', $f );
      my $file_content = read_file( $f );
      $file_content =~ s/(?<!README)\.md\)/\)/g; # Change links
      if ( $f =~ /proyecto/ ) {
	  $file_content =~ s{/(\d)}{/$1.md}g; # Change back for links to prácticas
      }
      if ( $f =~ /temas/ ) {
	  my ($breadcrumb) = ($file_content =~ /<!--@(.+)-->/gs);
	  $file_content = $layout_preffix."apuntes: T\n$breadcrumb---\n\n".$file_content;
	  write_file($f, $file_content);
	  $git->command('add', $f );
      } else {
	  if ( $f eq 'README.md' ) {
	      $f = 'index.md';
	  }
	  $file_content = $layout_preffix."\n---\n".$file_content;
	  write_file($f, $file_content );
	  $git->command('add', 'index.md' );
	  unlink('README.md');
      }
      $git->command('commit','-am', "Sync $f de master a gh-pages\n\nTras ==>\n$commit_msg");
      say "Procesando $f";
    }
    $git->command(qw/checkout master/); #back to original
  }
};

run_hook($0, @ARGV);

sub run_command {
  my $git = shift;
  my $command = shift;
  my $run_command = $git->command( $command );
  return $run_command->final_output;
}

=head1 NAME

git-hooks.pl - post-commit hooks to sync markdown pages with GitHub pages

=head2 SYNOPSIS

First you need to install C<Git::Hooks> and C<File::Slurp>. I use say,
so you will need perl > 5.10. Besides, you need to locate Git.pm and
copy it where the file can find it. That depends on the OS and perl
installation you're using (I use perlbrew), In my case it was:

  bash% cp /usr/share/perl5/Git.pm ~/perl5/perlbrew/perls/perl-5.16.1/lib/site_perl/5.16.1/

Then copy git-hooks.pl to .git/hooks, make it runnable (chmod +x
    git-hooks) and then

  bash% ln -s git-hooks.pl post-commit

Any trouble, just check the L<Git::Hooks> manual.

=head2 DESCRIPTION

Inpired by
L<http://stackoverflow.com/questions/15214762/how-can-i-sync-documentation-with-github-pages>
this answer by Cory Gross in StackOverflow, the ever helpful site. It
was adapted to Perl instead of bash.

Besides including Jekyll YAML headers in the files, it eliminates
C<.md> suffixes to convert them to the correct URL in Github Pages. 

=head1 LICENSE

This is released under the Artistic License. See L<perlartistic>.

=head2 AUTHOR

JJ Merelo, L<jj@merelo.net>
