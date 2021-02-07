// TODO: extract parts to common repo
use <../../poly555/openscad/lib/basic_shapes.scad>;
use <../../poly555/openscad/lib/enclosure.scad>;
use <../../poly555/openscad/lib/diagonal_grill.scad>;

include <shared_constants.scad>;

// TODO: expose LIP_BOX_DEFAULT_LIP_HEIGHT
ENCLOSURE_BOTTOM_HEIGHT = ENCLOSURE_FLOOR_CEILING + 3;
ENCLSOURE_TOP_HEIGHT = ENCLOSURE_HEIGHT - ENCLOSURE_BOTTOM_HEIGHT;

module _pot_walls(
    diameter_bleed = 0,
    height_bleed = 0
) {
    e = .0321;

    y = PCB_Y + PCB_POT_POSITIONS[0][1];

    module _well() {
        diameter = WHEEL_DIAMETER + diameter_bleed * 2;
        z = ENCLOSURE_HEIGHT - WHEEL_HEIGHT - ENCLOSURE_FLOOR_CEILING
            - height_bleed;

        intersection() {
            translate([ENCLOSURE_WALL - e, y - diameter / 2 - e, 0]) {
                cube([
                    ENCLOSURE_WIDTH - ENCLOSURE_WALL * 2 - e * 2,
                    diameter + e * 2,
                    100
                ]);
            }

            for (xy = PCB_POT_POSITIONS) {
                translate([PCB_X + xy.x, y, z]) {
                    cylinder(
                        d = diameter,
                        h = ENCLOSURE_HEIGHT - z - ENCLOSURE_FLOOR_CEILING + e
                    );
                }
            };
        }
    }

    module _shaft_to_base() {
        z = PCB_Z + PCB_HEIGHT + PTV09A_POT_BASE_HEIGHT;

        for (xy = PCB_POT_POSITIONS) {
            translate([PCB_X + xy.x, y, z]) {
                cylinder(
                    d = PTV09A_POT_ACTUATOR_DIAMETER + diameter_bleed * 2,
                    h = ENCLOSURE_HEIGHT - z - ENCLOSURE_FLOOR_CEILING + e
                );
            }
        };
    }

    _well();
    _shaft_to_base();
}

module enclosure(
    width = ENCLOSURE_WIDTH,
    length = ENCLOSURE_LENGTH,
    height = ENCLOSURE_HEIGHT,

    wall = ENCLOSURE_WALL,
    inner_wall = ENCLOSURE_INNER_WALL,
    floor_ceiling = ENCLOSURE_FLOOR_CEILING,
    gutter = ENCLOSURE_INTERNAL_GUTTER,

    grill_depth = 1,
    grill_gutter = 3,
    grill_ring = 2,

    side_overexposure = ENCLOSURE_SIDE_OVEREXPOSURE,

    fillet = 2,
    tolerance = DEFAULT_TOLERANCE,

    show_top = true,
    show_bottom = true,

    enclosure_bottom_position = 0
) {
    e = 0.0321;

    module _half(h, lip) {
        enclosure_half(
            width = width, length = length, height = h,
            wall = wall,
            floor_ceiling = floor_ceiling,
            add_lip = lip,
            remove_lip = !lip,
            fillet = fillet,
            tolerance = tolerance,
            include_tongue_and_groove = true,
            tongue_and_groove_end_length = undef,
            $fn = DEFAULT_ROUNDING
        );
    }

    module _component_walls(is_cavity = false) {
        $fn = is_cavity ? HIDEF_ROUNDING : DEFAULT_ROUNDING;

        Z_PCB_TOP = Z_PCB_TOP + (is_cavity ? -e : 0);

        bleed = is_cavity ? tolerance : inner_wall;

        function get_height(z, expose = is_cavity) =
            height - z + (expose ? e : e - floor_ceiling);

        translate([
            PCB_X + PCB_LED_POSITION.x,
            PCB_Y + PCB_LED_POSITION.y,
            Z_PCB_TOP
        ]) {
            cylinder(
                d = LED_DIAMETER + bleed * 2,
                h = get_height(Z_PCB_TOP)
            );
        }

        translate([
            PCB_X + PCB_SPEAKER_POSITION.x,
            PCB_Y + PCB_SPEAKER_POSITION.y,
            Z_PCB_TOP
        ]) {
            cylinder(
                d = SPEAKER_DIAMETER + bleed * 2,
                h = get_height(Z_PCB_TOP, false) +
                    (is_cavity ? floor_ceiling - grill_depth : 0)
            );
        }

        if (!is_cavity) {
            _pot_walls(inner_wall);
        }
    }

    module _grill(depth = grill_depth, coverage = .5, _fillet = 1) {
        _depth = depth + e;
        _length = (length - grill_gutter * 2) * coverage;

        y = length - _length - grill_gutter;
        z = height - depth;

        module _rounding(height = _depth) {
            rounded_xy_cube(
                [width - grill_gutter * 2, _length, height],
                radius = _fillet,
                $fn = DEFAULT_ROUNDING
            );
        }

        module _diagonal_grill(height = _depth) {
            diagonal_grill(
                width - grill_gutter * 2, _length, height,
                size = 2,
                angle = 45
            );
        }

        difference() {
            translate([grill_gutter, y, z]) {
                intersection() {
                    _rounding();
                    translate([0, 0, -e]) _diagonal_grill(_depth + e * 2);
                }
            }

            translate([PCB_X, PCB_Y, 0]) {
                for (xy = PCB_POT_POSITIONS) {
                    translate([xy.x, xy.y, z - e]) {
                        cylinder(
                            d = WHEEL_DIAMETER + grill_ring * 2,
                            h = _depth + e * 2
                        );
                    }
                };

                translate([
                    PCB_LED_POSITION.x,
                    PCB_LED_POSITION.y,
                    z - e
                ]) {
                    cylinder(
                        d = LED_DIAMETER + grill_ring * 2,
                        h = _depth + e * 2
                    );
                }
            }
        }
    }

    module _pot_cavities() {
        well_z = ENCLOSURE_HEIGHT - WHEEL_HEIGHT - e;
        shaft_to_base_z = PCB_Z + PCB_HEIGHT + PTV09A_POT_BASE_HEIGHT - e;

        well_diameter = WHEEL_DIAMETER + tolerance * 4; // intentionally loose
        exposure_diameter = PTV09A_POT_ACTUATOR_BASE_DIAMETER + tolerance * 2;

        module _well(_height = height - well_z + e) {
            cylinder(
                d = well_diameter,
                h = _height,
                $fn = HIDEF_ROUNDING
            );
        }

        module _well_dfm(
            coverages = [1, .5, 0, 0],
            layer_height = DEFAULT_FDM_LAYER_HEIGHT
        ) {
            function get_span(
                coverage = 0,
                minimum = exposure_diameter,
                maximum = well_diameter
            ) = (
                minimum + coverage * (maximum - minimum)
            );

            intersection() {
                translate([0, 0, layer_height * -len(coverages) - e]) {
                    cylinder(
                        d = well_diameter + e * 2,
                        h = layer_height * len(coverages) + e * 2,
                        $fn = HIDEF_ROUNDING
                    );
                }

                for (i = [0 : len(coverages) - 1]) {
                    width = get_span(coverage = coverages[max(0, i - 1)]);
                    length = get_span(coverage = coverages[i]);

                    translate([0, 0, (i + 1) * -layer_height]) {
                        rotate([0, 0, (i % 2) * 90]) {
                            translate([width / -2, length / -2, 0]) {
                                cube([width, length, layer_height + e]);
                            }
                        }
                    }
                }
            }
        }

        for (xy = PCB_POT_POSITIONS) {
            translate([wall + gutter + xy.x, PCB_Y + xy.y, 0]) {
                translate([0, 0, well_z]) {
                    _well();
                    _well_dfm();
                }

                translate([0, 0, shaft_to_base_z]) {
                    cylinder(
                        d = exposure_diameter,
                        h = height - shaft_to_base_z + e,
                        $fn = HIDEF_ROUNDING
                    );
                }
            };
        }
    }

    module _switch_clutch_cavity() {
        y_tolerance = tolerance * 2; // intentionally loose

        y = get_switch_clutch_y(0) - y_tolerance;

        length = SWITCH_CLUTCH_LENGTH
            + SWITCH_ACTUATOR_TRAVEL
            + y_tolerance * 2;
        height = SWITCH_CLUTCH_HEIGHT + Z_PCB_TOP + e;

        translate([-e, y, -e]) {
            cube([wall + e * 2, length, height]);
        }
    }

    module _switch_clutch_wall() {
        width = inner_wall;
        length = SWITCH_BASE_LENGTH;
        _height = ENCLSOURE_TOP_HEIGHT - SWITCH_CLUTCH_HEIGHT
            - floor_ceiling;

        translate([
            SWITCH_CLUTCH_WEB_X - side_overexposure
                + SWITCH_CLUTCH_WEB_WIDTH + tolerance * 2,
            PCB_Y + PCB_SWITCH_POSITION[1] - SWITCH_ORIGIN[1],
            height - floor_ceiling - _height
        ]) {
            cube([width, length, _height + e]);
        }
    }

    if (show_bottom) {
        // TODO: ensure PCB and battery are held into place

        translate([0, ENCLOSURE_LENGTH * enclosure_bottom_position, -e]) {
            _half(ENCLOSURE_BOTTOM_HEIGHT, false);
        }
    }

    if (show_top) {
        _switch_clutch_wall();

        difference() {
            union() {
                translate([0, 0, height]) {
                    mirror([0, 0, 1]) {
                        _half(ENCLSOURE_TOP_HEIGHT, true);
                    }
                }

                _component_walls();
            }

            _component_walls(is_cavity = true);
            _grill();
            _pot_cavities();
            _switch_clutch_cavity();
        }
    }
}
