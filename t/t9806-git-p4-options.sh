#!/bin/sh

test_description='git-p4 options'

. ./lib-git-p4.sh

test_expect_success 'start p4d' '
	start_p4d
'

test_expect_success 'init depot' '
	(
		cd "$cli" &&
		echo file1 >file1 &&
		p4 add file1 &&
		p4 submit -d "change 1" &&
		echo file2 >file2 &&
		p4 add file2 &&
		p4 submit -d "change 2" &&
		echo file3 >file3 &&
		p4 add file3 &&
		p4 submit -d "change 3"
	)
'

test_expect_success 'clone no --git-dir' '
	test_must_fail "$GITP4" clone --git-dir=xx //depot
'

test_expect_success 'clone --branch' '
	"$GITP4" clone --branch=refs/remotes/p4/sb --dest="$git" //depot &&
	test_when_finished cleanup_git &&
	(
		cd "$git" &&
		git ls-files >files &&
		test_line_count = 0 files &&
		test_path_is_file .git/refs/remotes/p4/sb
	)
'

test_expect_success 'clone --changesfile' '
	cf="$TRASH_DIRECTORY/cf" &&
	test_when_finished "rm \"$cf\"" &&
	printf "1\n3\n" >"$cf" &&
	"$GITP4" clone --changesfile="$cf" --dest="$git" //depot &&
	test_when_finished cleanup_git &&
	(
		cd "$git" &&
		git log --oneline p4/master >lines &&
		test_line_count = 2 lines
		test_path_is_file file1 &&
		test_path_is_missing file2 &&
		test_path_is_file file3
	)
'

test_expect_success 'clone --changesfile, @all' '
	cf="$TRASH_DIRECTORY/cf" &&
	test_when_finished "rm \"$cf\"" &&
	printf "1\n3\n" >"$cf" &&
	test_must_fail "$GITP4" clone --changesfile="$cf" --dest="$git" //depot@all
'

# imports both master and p4/master in refs/heads
# requires --import-local on sync to find p4 refs/heads
# does not update master on sync, just p4/master
test_expect_success 'clone/sync --import-local' '
	"$GITP4" clone --import-local --dest="$git" //depot@1,2 &&
	test_when_finished cleanup_git &&
	(
		cd "$git" &&
		git log --oneline refs/heads/master >lines &&
		test_line_count = 2 lines &&
		git log --oneline refs/heads/p4/master >lines &&
		test_line_count = 2 lines &&
		test_must_fail "$GITP4" sync &&

		"$GITP4" sync --import-local &&
		git log --oneline refs/heads/master >lines &&
		test_line_count = 2 lines &&
		git log --oneline refs/heads/p4/master >lines &&
		test_line_count = 3 lines
	)
'

test_expect_success 'clone --max-changes' '
	"$GITP4" clone --dest="$git" --max-changes 2 //depot@all &&
	test_when_finished cleanup_git &&
	(
		cd "$git" &&
		git log --oneline refs/heads/master >lines &&
		test_line_count = 2 lines
	)
'

test_expect_success 'clone --keep-path' '
	(
		cd "$cli" &&
		mkdir -p sub/dir &&
		echo f4 >sub/dir/f4 &&
		p4 add sub/dir/f4 &&
		p4 submit -d "change 4"
	) &&
	"$GITP4" clone --dest="$git" --keep-path //depot/sub/dir@all &&
	test_when_finished cleanup_git &&
	(
		cd "$git" &&
		test_path_is_missing f4 &&
		test_path_is_file sub/dir/f4
	) &&
	cleanup_git &&
	"$GITP4" clone --dest="$git" //depot/sub/dir@all &&
	(
		cd "$git" &&
		test_path_is_file f4 &&
		test_path_is_missing sub/dir/f4
	)
'

test_expect_success 'kill p4d' '
	kill_p4d
'

test_done