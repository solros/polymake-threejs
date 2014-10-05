#  Copyright (c) 1997-2014
#  Ewgenij Gawrilow, Michael Joswig (Technische Universitaet Berlin, Germany)
#  http://www.polymake.org
#
#  This program is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; either version 2, or (at your option) any
#  later version: http://www.gnu.org/licenses/gpl.txt.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#-------------------------------------------------------------------------------

# Interface to three.js for online polymake.
#
# This file only provides the basic functionality.  Visualization of polymake's various object types
# triggers code implemented in apps/*/rules/threejs.rules.


package ThreeJS_online::File;

our @ISA = "ThreeJS::File";


package ThreeJS_online::PointSet;

our @ISA = "ThreeJS::PointSet";


package ThreeJS_online::Wire;

our @ISA = "ThreeJS::Wire";


package ThreeJS_online::Solid;

our @ISA = "ThreeJS::Solid";

1

