package App::GitHooks::Plugin::DetectCommitNoVerify;

use strict;
use warnings;

use base 'App::GitHooks::Plugin';

# External dependencies.
use Capture::Tiny qw();

# Internal dependencies.
use App::GitHooks::Constants qw( :PLUGIN_RETURN_CODES );
use App::GitHooks::Hook::PreCommit;


=head1 NAME

App::GitHooks::Plugin::DetectCommitNoVerify - Find out when someone uses --no-verify and append the pre-commit checks to the commit message.


=head1 DESCRIPTION

Sometimes you just have to use C<--no-verify> to get past the checks and commit
as fast as possible. To prevent this from being too tempting, this plugin
checks when you use --no-verify and runs the pre-commit checks if you've
skipped them. It will let you commit even if the pre-commit checks fail, but it
will add their output to the commit message for posterity (and public shaming).


=head1 VERSION

Version 1.0.3

=cut

our $VERSION = '1.0.3';


=head1 METHODS

=head2 run_prepare_commit_msg()

Code to execute as part of the prepare-commit-msg hook.

  my $success = App::GitHooks::Plugin::DetectCommitNoVerify->run_prepare_commit_msg();

=cut

sub run_prepare_commit_msg
{
	my ( $class, %args ) = @_;
	my $app = delete( $args{'app'} );
	my $commit_message = delete( $args{'commit_message'} );
	my $repository = $app->get_repository();

	# Check if we've run the pre-commit hook.
	return $PLUGIN_RETURN_SKIPPED
		if -e '.git/COMMIT-MSG-CHECKS';

	# Check the changes and gather the output.
	my $changes_pass;
	my $stdout = Capture::Tiny::capture_stdout(
		sub
		{
			# Pretend we're running the pre-commit hook here to gather its output.
			my $local_app = $app->clone(
				name => 'pre-commit',
			);

			# Git commit messages don't seem to like utf8, so force disabling it.
			my $terminal = $local_app->get_terminal();
			$terminal->is_utf8(0);

			# Run all the tests for the pre-commit hook.
			$changes_pass = App::GitHooks::Hook::PreCommit::run_all_tests( $local_app );
		}
	);

	if ( !$changes_pass )
	{
		# "git revert" bypasses the pre-commit hook, so we can only use use the
		# prepare-commit-msg hook to catch any show-stoppers.
		# Since prepare-commit-msg doesn't support --no-verify, we should only
		# perform the essential checks when we're analyzing a revert. Note that you
		# can still do chmod -x .git/hooks/prepare-commit-msg to force-bypass this
		# hook in this case.
		my $staged_changes = $app->get_staged_changes();
		if ( $staged_changes->is_revert() )
		{
			chomp( $stdout );
			print $stdout, "\n";
			print "\n";
			print $app->color( 'red', "Fix the errors above and use 'git commit' to complete the revert." ) . "\n";
			return $PLUGIN_RETURN_FAILED;
		}

		# If output was generated by the pre-commit hooks, append it to the commit
		# message.
		if ( $stdout =~ /\w/ )
		{
			chomp( $stdout );

			# Git commit messages don't support ANSI control characters (which we
			# use for colors), so we need to strip those out.
			$stdout =~ s/\e\[[\d;]*[a-zA-Z]//g;

			# We need to append $stdout to $commit_message, as $commit_message will
			# contain the message passed via -m and this should be at the top of
			# the final message.
			$commit_message->update_message( $commit_message->get_message() . "\n\n" . $stdout );
		}
	}

	return $PLUGIN_RETURN_PASSED;
}


=head1 BUGS

Please report any bugs or feature requests through the web interface at
L<https://github.com/guillaumeaubert/App-GitHooks-Plugin-DetectCommitNoVerify/issues/new>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc App::GitHooks::Plugin::DetectCommitNoVerify


You can also look for information at:

=over

=item * GitHub's request tracker

L<https://github.com/guillaumeaubert/App-GitHooks-Plugin-DetectCommitNoVerify/issues>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/app-githooks-plugin-detectcommitnoverify>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/app-githooks-plugin-detectcommitnoverify>

=item * MetaCPAN

L<https://metacpan.org/release/App-GitHooks-Plugin-DetectCommitNoVerify>

=back


=head1 AUTHOR

L<Guillaume Aubert|https://metacpan.org/author/AUBERTG>,
C<< <aubertg at cpan.org> >>.


=head1 COPYRIGHT & LICENSE

Copyright 2013-2016 Guillaume Aubert.

This code is free software; you can redistribute it and/or modify it under the
same terms as Perl 5 itself.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the LICENSE file for more details.

=cut

1;
