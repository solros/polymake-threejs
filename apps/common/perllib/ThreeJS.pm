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
   my $title=$self->title || "unnamed";

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

sub newGeometry {
	my ($self, $var) = @_;
	return <<"%"
	var $var = new THREE.Geometry();
%
}

sub newVertex {
	my ($self, $var, $coords) = @_;
	return <<"%"
	$var.vertices.push(new THREE.Vector3($coords));
%
}

sub newPoint {
	my ($self, $var, $coords, $size) = @_;
	my $radius = $size/50;
	my $mat = $var."_material";
	return <<"%"
	var sphere = new THREE.Mesh(new THREE.SphereGeometry($radius), $mat);
	sphere.position.set($coords);
	scene.add(sphere);
%
}

sub newMaterial {
	my ($self, $var, $coords) = @_;
	my $mat = $var."_material";
	return <<"%"
	var $mat = new THREE.ParticlesBasicMaterial();
%
}


sub pointsToString {
    my ($self, $var)=@_;

    my $labels=$self->source->VertexLabels; # TODO: support labels
    
    my $text = "";

	if ($self->source->VertexStyle !~ $Visual::hidden_re){
		my @coords = Utils::pointCoords($self);

		$text .= $self->newGeometry($var);
		$text .= "\n	<!-- point style -->";

		my $vertex_color=$self->source->VertexColor;
		my $thickness = $self->source->VertexThickness || 1;

		if (is_code($vertex_color) || is_code($thickness)){
			die "not yet supported";
		}

		my $hexstring = Utils::rgbToHex(@$vertex_color);
		my $material_string = "color: $hexstring, size: $thickness,";
		$text .= "\n	var points_material = new THREE.MeshBasicMaterial({$material_string});\n\n";
		
		$text .= "	<!-- POINTS -->\n";
	
		foreach (@coords){
			$text .= $self->newPoint($var, $_, $thickness);
		}
		
		$text .= "\n";
	}
	
	return $text;
}

sub verticesToString {
	my ($self, $var) = @_; 

	my $text = "";
	
    my @coords = Utils::pointCoords($self);
    $text .= "\n  <!-- VERTICES -->\n";
    foreach (@coords) {
        $text .= $self->newVertex($var, $_);
   }
	return $text;
}


sub toString {
    my ($self, $trans)=@_;
    $self->pointsToString("points");
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
    $self->header("lines") . $self->pointsToString("points") . $self->linesToString . $self->trailer;
}


##############################################################################################
#
#  Solid 2-d or 3-d body
#
package ThreeJS::Solid;
use Polymake::Struct (
   [ '@ISA' => 'PointSet' ],
);


sub header {
	my ($self, $var) = @_;
	return $self->newGeometry($var);
}


sub trailer {
	my ($self, $var) = @_;
	my $mat = $var."_material";
	return <<"%"
	$var.computeFaceNormals();
	$var.computeVertexNormals();
	var object = new THREE.Mesh($var, $mat);
	scene.add(object);
%
}

sub newFace {
	my ($self, $var, $indices) = @_;
	return <<"%"
	$var.faces.push(new THREE.Face3($indices));
%
}

sub newLine {
	my ($self, $var) = @_;
	my $mat = $var."_material";
	return <<"%"
	scene.add(new THREE.Line($var, $mat));
	
%
}


sub facesToString {
    my ($self, $trans, $var)=@_;

    my $transp=$self->source->FacetTransparency || 1;
    my $facet_color=$self->source->FacetColor;
    my $edge_color=$self->source->EdgeColor;

    my $text = "";

	### FACETS
	my $facets = new Array<Array<Int>>($self->source->Facets);
	

	if ($self->source->FacetStyle !~ $Visual::hidden_re){
		$text .= $self->header($var);
		$text .= $self->verticesToString($var);
		$text .= "\n  <!-- facet style -->\n"; 
		my $mat = $var."_material";

		if (!is_code($facet_color)) {
			my $hexstring = Utils::rgbToHex(@$facet_color);
			my $material_string = "color: $hexstring, opacity: $transp,";
			$text .= <<"%"
   var $mat = new THREE.MeshBasicMaterial({$material_string});
	$mat.side = THREE.DoubleSide;
	
%
    	} else {
			$text .= "\n    var materials = [";
			foreach (my $i = 0; $i< @$facets; ++$i) {
            my $hexstring = Utils::rgbToHex(@{$facet_color->($i)});
            $text .= "\n		new THREE.MeshBasicMaterial({color:$hexstring}),"; 
			}
			$text .= <<"%"	
	];
	var $mat = new THREE.MeshFaceMaterial(materials);
	$mat.side = THREE.DoubleSide;
%
		}

    
    	# draw facets
		$text .= "\n  <!-- FACETS --> \n";  
		for (my $facet = 0; $facet<@$facets; ++$facet) {
			for (my $triangle = 0; $triangle<@{$facets->[$facet]}-2; ++$triangle) {
				my @vs = @{$facets->[$facet]}[0, $triangle+1, $triangle+2];
					$text .= $self->newFace($var, join(", ", @vs));
				}
				$text.="\n";
		}
		$text .= $self->trailer($var);
	}
	



	## EDGES	
	my $line_thick = $self->source->EdgeThickness || 1;
	
	if ($self->source->EdgeStyle !~ $Visual::hidden_re){
		my $var = "line";
		my $mat = "line_material";
		$text .= "\n  <!-- edge style -->\n"; 
		if (is_code($edge_color)) {
			die "not yet supported";
		}
		my $hexstring = Utils::rgbToHex(@$edge_color);
		my $material_string = "color: $hexstring, linewidth: $line_thick, ";
		$text .= "	var $mat = new THREE.LineBasicMaterial({$material_string});\n";
		
    
    	# draw edges
		$text .= "\n  <!-- EDGES --> \n";  
		my @coords = Utils::pointCoords($self);
		print join "\n", @coords;
		for (my $facet = 0; $facet<@$facets; ++$facet) {
			$text .= $self->newGeometry($var);
			
			foreach (@{$facets->[$facet]}) {
				$text .= $self->newVertex($var, $coords[$_]);
			}
			# first vertex again
			$text .= $self->newVertex($var, $coords[$facets->[$facet]->[0]]);
			$text .= $self->newLine($var);
		}
	}
	

	return $text;
}

sub toString {
	my ($self, $transform)=@_;
	return $self->pointsToString("points") . $self->facesToString($transform, "faces");
}



package ThreeJS::Utils;

sub rgbToHex {    
	my $red=shift;
	my $green=shift;
	my $blue=shift;
	my $hex = sprintf ("0x%2.2X%2.2X%2.2X", $red*255, $green*255, $blue*255);
	return ($hex);
}

sub pointCoords {
	my ($self) = @_;
	my @coords = ();
   my $d = is_object($self->source->Vertices) ? $self->source->Vertices->cols : 3;
	foreach (@{$self->source->Vertices}) {
		my $point=ref($_) ? Visual::print_coords($_) : "$_".(" 0"x($d-1));
		$point =~ s/\s+/, /g;
		push @coords, $point;
	}
	return @coords;
}


1

