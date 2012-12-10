# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: libraries.sh - part of the BeakerLib project
#   Description: Functions for importing separate libraries
#
#   Author: Petr Muller <muller@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

: <<'=cut'
=pod

=head1 NAME

BeakerLib - libraries - mechanism for loading shared test code from libraries

=head1 DESCRIPTION

This file contains functions for bringing external code into the test
namespace.

=head1 FUNCTIONS

=cut

# Extract a location of an original sourcing script from $0
__INTERNAL_extractOrigin(){
  local SOURCE="$0"
  local DIR="$( dirname "$SOURCE" )"
  while [ -h "$SOURCE" ]
  do
      SOURCE="$(readlink "$SOURCE")"
      [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
      DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
  done
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

  echo "$DIR"
}

# Traverse directories upwards and search for the matching path
__INTERNAL_rlLibrarySearch() {
  local DIRECTORY="$1"
  local COMPONENT="$2"
  local LIBRARY="$3"

  while [ "$DIRECTORY" != "/" ]
  do
    DIRECTORY="$( dirname $DIRECTORY )"
    if [ -d "$DIRECTORY/$COMPONENT" ]
    then
      if [ -f "$DIRECTORY/$COMPONENT/Library/$LIBRARY/lib.sh" ]
      then
        echo "$DIRECTORY/$COMPONENT/Library/$LIBRARY/lib.sh"
        break
      fi
    fi
  done
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# rlImport
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head3 rlImport

Imports code provided by one or more libraries into the test namespace.
The library search mechanism is based on Beaker test hierarchy system, i.e.:

/component/type/test-name/test-file

When test-file calls rlImport with 'foo/bar' parameter, the directory path
is traversed upwards, and a check for presence of the test /foo/Library/bar/
will be performed. This means this function needs to be called from
the test hierarchy, not e.g. the /tmp directory.

Usage:

    rlImport LIBRARY [LIBRARY2...]

=over

=item LIBRARY

Must have 'component/library' format. Identifies the library to import.

=back

Returns 0 if the import of all libraries was successful. Returns non-zero
if one or more library failed to import.

=cut

rlImport() {
  local RESULT=0

  if [ -z "$1" ]
  then
    rlLogError "rlImport: At least one argument needs to be provided"
    return 1
  fi

  # Process all arguments
  while [ -n "$1" ]
  do

    # Extract two identifiers from an 'component/library' argument
    local COMPONENT=$( echo $1 | cut -d '/' -f 1 )
    local LIBRARY=$( echo $1 | cut -d '/' -f 2 )

    if [ -z "$COMPONENT" ] || [ -z "$LIBRARY" ] || [ "$COMPONENT/$LIBRARY" != "$1" ]
    then
      rlLogError "rlImport: Malformed argument [$1]"
      RESULT=1
      shift; continue;
    fi

    rlLogDebug "rlImport: Searching for library $COMPONENT/$LIBRARY"

    local TRAVERSE_ROOT="$( __INTERNAL_extractOrigin )"
    rlLogDebug "rlImport: Starting search at: $TRAVERSE_ROOT"
    local LIBFILE="$(  __INTERNAL_rlLibrarySearch $TRAVERSE_ROOT $COMPONENT $LIBRARY )"

    if [ -z "$LIBFILE" ]
    then
      rlLogError "rlImport: Could not find library $1"
      RESULT=1
      shift; continue;
    fi

    # Try to extract a prefix comment from the file found
    # Prefix comment looks like this:
    # library-prefix = wee
    local PREFIX="$( grep -E "library-prefix = [a-zA[z_][a-zA-Z0-9_]*.*" $LIBFILE | sed 's|.*library-prefix = \([a-zA-Z_][a-zA-Z0-9_]*\).*|\1|')"
    if [ -z "$PREFIX" ]
    then
      rlLogError "rlImport: Could not extract prefix from library $1"
      RESULT=1
      shift; continue;
    fi

    # Construct the validating function
    # Its supposed to be called 'prefixVerify'
    local VERIFIER="${PREFIX}Verify"
    rlLogDebug "Constructed verifier function: $VERIFIER"

    # Cycle detection: if validating function is available, the library
    # is imported already
    if eval $VERIFIER &>/dev/null
    then
      rlLogInfo "rlImport: Library $1 imported already"
      shift; continue;
    fi

    # Try to source the library
    . $LIBFILE

    # Call the validation callback of the function
    if ! eval $VERIFIER
    then
      rlLogError "rlImport: Import of library $1 was not successful (callback failed)"
      RESULT=1
      shift; continue;
    fi

    shift;
  done

  return $RESULT
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# AUTHORS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Petr Muller <muller@redhat.com>

=back

=cut
