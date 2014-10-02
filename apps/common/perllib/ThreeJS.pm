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

# Interface to ThreeJS.
#
# This file only provides the basic functionality.  Visualization of polymake's various object types
# triggers code implemented in apps/*/rules/threejs.rules.

package ThreeJS::File;

use Polymake::Struct (
   [ new => '$' ],
   [ '$title' => '#1' ],
   '@geometries',
   [ '$unnamed' => '0' ],
   [ '$transform' => 'undef' ],
);

sub append {
   my $self = shift;
   push @{$self->geometries}, @_;
   foreach (@_) {
      if (length($_->name)) {
         $self->title //= $_->name;
      } else {
         $_->name="unnamed__" . ++$self->unnamed;
      }
   }
}

sub header {
   my ($self,$trans) = @_;
   my $who=$ENV{USER};
   my $when=localtime();
   my $title=$self->title // "unnamed";

   my $xaxis = $trans->col(1);
   my $yaxis = $trans->col(2);
   my $zaxis = $trans->col(3);
   return <<"%";
<!--
polymake for $who
$when
$title
-->

<html>
	<head>
		<title>$title</title>
		<style>canvas { width: 100%; height: 100% }</style>
	</head>

<body>
<script src="js/three.min.js"></script>
<script src="js/controls/TrackballControls.js"></script>

<script>
	var scene = new THREE.Scene();
	var camera = new THREE.PerspectiveCamera(75, window.innerWidth/window.innerHeight, 0.1, 1000);
	
	var controls = new THREE.TrackballControls( camera );
				
	var renderer = new THREE.CanvasRenderer();
	renderer.setSize(window.innerWidth, window.innerHeight);
	document.body.appendChild(renderer.domElement);

	camera.position.z = 5;		
%
}

sub trailer {
    return <<"%";
	var render = function () {
		requestAnimationFrame(render);

		controls.update();
		renderer.render(scene, camera);
	};

	render();
</script>

</body>
</html>
%
}

sub toString {
   my ($self)=@_;
   my $trans= defined($self->transform) ? $self->transform : (new Matrix<Float>([[1,0,0,0],[0,2,0,-0.4],[0,0,2,-1],[0,0,0,1]]));
   $self->header($trans) . join("", map { $_->toString($trans) } @{$self->geometries}) . $self->trailer;
}

##############################################################################################
#
#  Basis class for all graphical objects handled by threejs
#
package ThreeJS::PointSet;
use Polymake::Struct (
   [ new => '$' ],
   [ '$source' => '#1' ],
   [ '$name' => '#1 ->Name' ],
);

# name without whitespace and such
# notice that "-", "{", and "}" occur in names of simplices of a TRIANGULATION
sub id {
   my ($self)=@_;
   my $id=$self->name;
   $id =~ s/[\s\{\}-]+//g;
   return $id;
}

sub header {
	return <<"%"

	var geometry = new THREE.Geometry();
	
%
}

sub trailer {
	return <<"%"

	geometry.computeFaceNormals();
	geometry.computeVertexNormals();
	var object = new THREE.Mesh(geometry, material);
	scene.add(object);

%
}

sub pointsToString {
    my ($self)=@_;
    my $id = $self->id; # this is used to make all ids globally unique

    my $d = is_object($self->source->Vertices) ? $self->source->Vertices->cols : 3;
    my $style=$self->source->VertexStyle;
    my $point_flag= is_code($style) || $style !~ $Visual::hidden_re ? "show" : "hide";
    my $color=$self->source->VertexColor;
    my $color_flag= is_code($color) ? "show" : "hide";
    my $k=0;
    my $labels=$self->source->VertexLabels;
#---
    my $thickness=$self->source->VertexThickness;
    my $thickness_flag= is_code($thickness) ? "show" : "hide";
    my @vertexcolor = ($color_flag eq "show") ? split(/ /, $color->(0)->toFloat) :  split(/ /, $color->toFloat);
    my $vcstring = join ",", @vertexcolor;
    
    my $text = "";


    # Point coloring
    if ($point_flag eq "show"){ 
        if ($color_flag eq "show"){
            my $i = 0;
            foreach my $e(@{$self->source->Vertices}){
                my @own_color_array = split(/ /, $color->($i)->toFloat);
                my $ocstring = join ",", @own_color_array;
                ++$i;
            }}

    }

    # Point definitions
    $text .= "\n  <!-- DEF POINTS -->\n";
    foreach (@{$self->source->Vertices}) {
        my $point=ref($_) ? Visual::print_coords($_) : "$_".(" 0"x($d-1));
        $point =~ s/\s+/, /g;
        $text .= "  geometry.vertices.push(new THREE.Vector3($point));\n";
        ++$k;
    }
    $text .= "\n";

    return $text;
}

sub toString {
    my ($self, $trans)=@_;
    $self->header . $self->pointsToString . $self->trailer;
}

##############################################################################################
#
#  Wire model (e.g. a graph)

package ThreeJS::Wire;
use Polymake::Struct (
   [ '@ISA' => 'PointSet' ],
);

sub linesToString {
    my ($self)=@_;
    my $id=$self->id;

    my $arrows=$self->source->ArrowStyle;
    my $style=$self->source->EdgeStyle;
    my $line_flag= is_code($style) || $style !~ $Visual::hidden_re ? "show" : "hide";
    my $thickness=$self->source->EdgeThickness;
    my $thickness_flag= is_code($thickness) ? "show" : "hide";
    my $color=$self->source->EdgeColor;
    my $color_flag= is_code($color) ? "show" : "hide";
    my @linecolor = ($color_flag eq "show") ? split(/ /, $color->($self->source->all_edges)) : split(/ /, $color->toFloat);
    my $lcstring = join ",", @linecolor;
    my $lsstring = "color=linecolor_$id, thick";
    if($arrows==1) {
        $lsstring .= ", arrows = -stealth, shorten >= 1pt";
    } elsif($arrows==-1) {
        $lsstring .= ", arrows = stealth-, shorten >= 1pt";
    }

    my $text ="";

    if ($line_flag eq "show"){

            if ($color_flag eq "show"){
                for (my $e=$self->source->all_edges; $e; ++$e) {
                    my $a=$e->[0]; my $b=$e->[1];
                    my $own_color =  $color->($e)->toFloat;
                    my @own_color_array = split(/ /, $color->($e)->toFloat);
                    my $ocstring = join ",", @own_color_array;
                }
        }


        my $labels=$self->source->EdgeLabels;

    }

    return $text;
}

sub toString {
    my ($self, $trans)=@_;
    $self->header . $self->pointsToString . $self->linesToString . $self->trailer;
}


##############################################################################################
#
#  Solid 2-d or 3-d body
#
package ThreeJS::Solid;
use Polymake::Struct (
   [ '@ISA' => 'PointSet' ],
);

sub facesToString {
    my ($self, $trans)=@_;
    my $id = $self->id; # this is used to make all ids globally unique

    my $transp=$self->source->FacetTransparency || 1;
    my $facet_color=$self->source->FacetColor;

    my $edge_color=$self->source->EdgeColor;


    my $text = "";


	### FACETS
	my $facets = new Array<Array<Int>>($self->source->Facets);


	if ($self->source->FacetStyle !~ $Visual::hidden_re){
		$text .= "\n  <!-- FACET STYLE -->\n"; 
		if (!is_code($facet_color)) {
			my $hexstring = rgbToHex(@$facet_color);
			my $material_string = "color: $hexstring, opacity: $transp,";
			$text .= <<"%"
   var material = new THREE.MeshBasicMaterial({$material_string});
	material.side = THREE.DoubleSide;
	
%
    	} else {
			$text .= "\n    var materials = [";
			foreach (my $i = 0; $i< @$facets; ++$i) {
            my $hexstring = rgbToHex(@{$facet_color->($i)});
            $text .= "\n		new THREE.MeshBasicMaterial({color:$hexstring}),"; 
			}
			$text .= <<"%"	
	];
	var material = new THREE.MeshFaceMaterial(materials);
	material.side = THREE.DoubleSide;
%
		}

    
    	# Draw Facets
		$text .= "\n  <!-- FACETS --> \n";  
		for (my $facet = 0; $facet<@$facets; ++$facet) {
			for (my $triangle = 0; $triangle<@{$facets->[$facet]}-2; ++$triangle) {
				my @vs = @{$facets->[$facet]}[0, $triangle+1, $triangle+2];
					$text .= "  geometry.faces.push(new THREE.Face3(";
					$text .= join(", ", @vs);
					$text.="));\n";
				}
				$text.="\n";
		}
	}
	



	## EDGES	
	my $line_thick = $self->source->EdgeThickness;
	
	if ($self->source->EdgeStyle !~ $Visual::hidden_re){
		$text .= "\n  <!-- Edge STYLE -->\n"; 
		if (!is_code($edge_color)) {
			my $hexstring = rgbToHex(@$edge_color);
			my $material_string = "color: $hexstring, linewidth: $line_thick, ";
			$text .= <<"%"
   var line_material = new THREE.LineBasicMaterial({$material_string});
	
%
    	} else {
		}

    
    	# draw edges
		$text .= "\n  <!-- EDGES --> \n";  
		for (my $facet = 0; $facet<@$facets; ++$facet) {
			$text .= "	var line_geometry = new THREE.Geometry();\n";
			foreach (@{$facets->[$facet]}) {
				my $v = vertexCoords($self, $_);
				$text .= <<"%" 
	line_geometry.vertices.push(new THREE.Vector3($v));
%
			}
			my $v = vertexCoords($self, $facets->[$facet]->[0]);
			$text .= <<"%" 
	line_geometry.vertices.push(new THREE.Vector3($v));
	var line = new THREE.Line(line_geometry, line_material);
	scene.add(line);
	
%
		}
	}
	

	return $text;
}

sub toString {
	my ($self, $transform)=@_;
	return $self->header . $self->pointsToString . $self->facesToString($transform) . $self->trailer;
}


sub vertexCoords {
	my ($self, $index) = @_;
	my $p = $self->source->Vertices->[$index];
	my $v = ref($p) ? Visual::print_coords($p) : "$p".(" 0"x($d-1));
	$v =~ s/\s+/, /g;
	return $v;
}

sub rgbToHex {    
	my $red=shift;
	my $green=shift;
	my $blue=shift;
	my $hex = sprintf ("0x%2.2X%2.2X%2.2X", $red*255, $green*255, $blue*255);
	return ($hex);
}

1

