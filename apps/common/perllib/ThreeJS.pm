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
   my ($self, $trans) = @_;
   print "trans:\n";
   print $trans;
   print "\n";
   my $who=$ENV{USER};
   my $when=localtime();
   my $title=$self->title || "unnamed";

   my $xaxis = $trans->col(1);
   my $yaxis = $trans->col(2);
   my $zaxis = $trans->col(3);
   
   my $view_point = join ", ", @ThreeJS::default::view_point;
   my $bgColor = Utils::rgbToHex(@ThreeJS::default::bgColor); # TODO: recognize different ways to define colors
   my $bgOp = $ThreeJS::default::bgOpacity;
   my $camera_angle = $ThreeJS::default::camera_angle;
   my $hither = $ThreeJS::default::hither;
   my $yon = $ThreeJS::default::yon;
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

<div id="model"></div>

<script src="js/three.min.js"></script>
<script src="js/controls/TrackballControls.js"></script>
<script src="js/Detector.js"></script>


<script>
	var container = document.getElementById( 'model' );
	var renderer = Detector.webgl? new THREE.WebGLRenderer(): new THREE.CanvasRenderer();

	renderer.setSize(window.innerWidth, window.innerHeight);
	renderer.setClearColor($bgColor, $bgOp);

	container.appendChild(renderer.domElement);


	var scene = new THREE.Scene();
	var camera = new THREE.PerspectiveCamera($camera_angle, window.innerWidth/window.innerHeight, $hither, $yon);
					
	camera.position.set($view_point);

	var controls = new THREE.TrackballControls(camera, container);
	
	var all_objects = [];
	var centroids = [];
%
}

sub trailer {
    return <<"%";

	var c = new THREE.Vector3();
	for (i = 0; i< all_objects.length; ++i) {
		var obj = all_objects[i];
		console.log(i);
	}

	var render = function () {

		requestAnimationFrame(render);

//		comment in for automatic explosion
//		explode(updateFactor());

		controls.update();
		renderer.render(scene, camera);
	};

	render();

	function computeCentroid(geom) {
		centroid = new THREE.Vector3();
		geom.vertices.forEach(function(v) {
			centroid.add(v);			
		});
		centroid.divideScalar(geom.vertices.length);
		return centroid;
	}

	function explode(factor) {
		var obj, c;
		for (var i = 0; i< all_objects.length; ++i) {
			obj = all_objects[i];
			c = centroids[i];
	
			obj.position.set(c.x*factor, c.y*factor, c.z*factor);
		}	
	}

	var pos = 150* Math.PI;

	function updateFactor() {
		pos++;
		return Math.sin(.01*pos)+1;
	}


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
	obj.add(sphere);
%
}

sub newLine {
	my ($self, $var) = @_;
	my $mat = $var."_material";
	return <<"%"
	obj.add(new THREE.Line($var, $mat));
	
%
}


sub newMaterial {
	my ($self, $var, $type) = @_;
	my $matvar = $var."_material";
	my $material;
	my $material_bracket1 = "({";
	my $material_bracket2 = "})";
	my $material_string = "";
	

	my $text = "";
	
	if ($type eq "Vertex") {
		$material = "MeshBasicMaterial";

		my $color = $self->source->VertexColor;
		my $col_string = Utils::rgbToHex(@$color);
		$material_string .= "color: $col_string, ";
		
	} elsif ($type eq "Point") {
		$material = "MeshBasicMaterial";
		
		my $color = $self->source->PointColor;
		my $col_string = Utils::rgbToHex(@$color);
		$material_string .= "color: $col_string, ";

	} elsif ($type eq "Facet") {
		my $transp = 1 - $self->source->FacetTransparency || 1;
		$material_string .= "transparent: true, opacity: $transp, ";

		my $color = $self->source->FacetColor;
		if (!is_code($color)) {
			$material = "MeshBasicMaterial";
			
			my $col_string = Utils::rgbToHex(@$color);
			$material_string .= "color: $col_string, ";
		} else {
			$material = "MeshFaceMaterial";
			$text .= "\n    var materials = [";
			foreach (my $i = 0; $i< @{$self->source->Facets}; ++$i) {
            my $hexstring = Utils::rgbToHex(@{$color->($i)});
            $text .= "\n		new THREE.MeshBasicMaterial({color: $hexstring, $material_string}),"; 
			}
			$text .= "\n	];\n";
		
			$material_string = "materials";
			$material_bracket1 = "(";
			$material_bracket2 = ")";
		}

	} elsif ($type eq "Edge") {
		$material = "LineBasicMaterial";
		
		my $thick = $self->source->EdgeThickness || 1;
		$material_string .= "linewidth: $thick, ";
		
		my $color = $self->source->EdgeColor;
		my $col_string = (is_code($color)) ? Utils::rgbToHex(@{$color->(0)}) : Utils::rgbToHex(@$color);
		$material_string .= "color: $col_string, ";
	}
	
	return <<"%"
	
	<!-- $type style -->
	$text
	var $matvar = new THREE.$material $material_bracket1 $material_string $material_bracket2;
	$matvar.side = THREE.DoubleSide;
	
%
}

sub header {
	return <<"%"
	var obj = new THREE.Object3D();
%
}

sub trailer {
	return <<"%"
	scene.add(obj);
	all_objects.push(obj);

%
}


sub pointsToString {
    my ($self, $var)=@_;

    my $labels=$self->source->VertexLabels; # TODO: support labels
    
    my $text = "";

	if ($self->source->VertexStyle !~ $Visual::hidden_re){
		my @coords = Utils::pointCoords($self);

		my $thickness = $self->source->VertexThickness || 1;
		

		$text .= $self->newMaterial("points", "Vertex");

		$text .= "\n	<!-- POINTS -->\n";
	
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

	$text .= <<"%";
	
	centroids.push(computeCentroid($var));

%

	return $text;
}


sub toString {
    my ($self, $trans)=@_;
    $self->header . $self->pointsToString("points") . $self->trailer;
}

##############################################################################################
#
#  Wire model (e.g. a graph)

package ThreeJS::Wire;
use Polymake::Struct (
   [ '@ISA' => 'PointSet' ],
);

sub newEdge {
	my ($self, $var, $a, $b) = @_;
	
	return $self->newGeometry($var) . $self->newVertex($var, $a) . $self->newVertex($var, $b) . $self->newLine($var);
}


sub linesToString {
    my ($self, $var)=@_;

	# TODO: arrows
#    my $arrows=$self->source->ArrowStyle;

 #   if($arrows==1) {
 #       $lsstring .= ", arrows = -stealth, shorten >= 1pt";
 #   } elsif($arrows==-1) {
 #       $lsstring .= ", arrows = stealth-, shorten >= 1pt";
 #   }

    my $text ="";

	if ($self->source->EdgeStyle !~ $Visual::hidden_re) {
		$text .= $self->newMaterial($var, "Edge");

		$text .= "\n	<!-- EDGES -->\n";

		my @coords = Utils::pointCoords($self);

		for (my $e=$self->source->all_edges; $e; ++$e) {
			$text .= $self->newEdge($var, $coords[$e->[0]], $coords[$e->[1]]);
		}
	}
	

	return $text;
}

sub toString {
    my ($self, $trans)=@_;
   $self->header . $self->pointsToString("points") . $self->linesToString("line") . $self->trailer;
}


##############################################################################################
#
#  Solid 2-d or 3-d body
#
package ThreeJS::Solid;
use Polymake::Struct (
   [ '@ISA' => 'PointSet' ],
);


sub newFace {
	my ($self, $var, $indices, $facet, $facet_color) = @_;
#	my $color;
	my $m_index = 0;
	if (is_code($facet_color)) {
#		print $facet."\t";
#		$color = join ", ", @{$facet_color->($facet)};
#		print $color."\n";
		$m_index = $facet;
	} else {
#		$color = Utils::rgbToHex(@{$facet_color});
	}
	return <<"%"
	$var.faces.push(new THREE.Face3($indices, undefined, undefined, $m_index));
%
}


sub facesToString {
    my ($self, $trans, $var)=@_;

    my $text = "";

	### FACETS
	my $facets = new Array<Array<Int>>($self->source->Facets);	

	if ($self->source->FacetStyle !~ $Visual::hidden_re){
		$text .= $self->newGeometry($var);
		$text .= $self->verticesToString($var);

		$text .= $self->newMaterial($var, "Facet");

    
    	# draw facets
		$text .= "\n  <!-- FACETS --> \n";  
		my $facet_color = $self->source->FacetColor;
		for (my $facet = 0; $facet<@$facets; ++$facet) {
			for (my $triangle = 0; $triangle<@{$facets->[$facet]}-2; ++$triangle) {
				my @vs = @{$facets->[$facet]}[0, $triangle+1, $triangle+2];
					$text .= $self->newFace($var, join(", ", @vs), $facet, $facet_color);
				}
				$text.="\n";
		}

		my $mat = $var."_material";
		$text .= <<"%"
	
	$var.computeFaceNormals();
	$var.computeVertexNormals();
	
	var object = new THREE.Mesh($var, $mat);
	obj.add(object);
	
%
	}
	



	## EDGES
	if ($self->source->EdgeStyle !~ $Visual::hidden_re){
		$var = "line";
		
		$text .= $self->newMaterial($var, "Edge");		
    
    	# draw edges
		$text .= "\n  <!-- EDGES --> \n";  
		my @coords = Utils::pointCoords($self);

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
	return $self->header . $self->pointsToString("points") . $self->facesToString($transform, "faces") . $self->trailer;
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

