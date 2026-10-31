// Radxa Cubie A7S: 40 mm fan bracket (parametric).  Units: mm.
//
// Holds a 40 x 40 x 10 mm fan 15 mm above the SoC heatsink, on the board's own four mounting holes (no glue, no drilling).
// "gauge" is a 10-minute thin plate to check the four hole positions on YOUR board before printing the bracket.
//
// Board data (50.8 x 50.8 mm board, four dia 2.7 holes on a 43.8 mm square, 3.5 mm from the edges): Radxa Cubie A7S product
// brief, "Mechanical Specification" (dl.radxa.com/cubie/a7s/docs/radxa_cubie_a7s_product_brief.pdf).  Not affiliated with Radxa.
// Fan data: 40 x 40 x 10 mm, mounting holes 32 x 32 mm, M3 screws.  Tested with the GeeekPi 4010 5 V fan (M3 x 16 screws + nuts).
//
// Printing: the plate lies flat on the bed and the posts point up (flip = true).  Use PETG or ASA for anything left on a running
// board: PLA/PLA+ softens at roughly 55-65 C and the chip area has been 66-80 C without a fan.  No supports needed.
// Hardware: 4 x M2.5 screws, 25 mm (+ nuts and washers) for the board; the fan's own 4 x M3 x 16 screws and nuts.
//
// STATUS: the gauge was printed and matched a real board; the bracket was printed, assembled and mounted on a real board with
// this heatsink height (heat_top = 9).  10-minute emulator load with the fan at full speed on this bracket: peak 45 C, average 42 C, no
// CPU throttling (without a fan the same load reached 80 C and throttled hard).  The 30 mm variant is untested.
// Designed with AI assistance (Claude, by Anthropic); dimensions checked and the parts printed and fitted by the human author.
// Licence: CC BY-NC-SA 4.0 (Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International), chosen by the author.
//
// part = "gauge"   -> thin hole-check plate, no posts
// part = "bracket" -> the real part (plate + 4 posts).  With flip = true the plate lies flat on the print bed and the
//                     posts point up, which is the easy way to print it.

part  = "gauge";
flip  = true;       // true: model is turned upside down so the plate sits flat on the print bed

board      = 50.8;
hole_d     = 2.7;   // board mounting holes
hole_off   = 3.5;
hole_pitch = board - 2*hole_off;     // 43.8

// ---- TODO: measure these on the real board ---------------------------------------------------------------------
heat_top = 9;       // board surface to the TOP of the fin tips on the SoC heatsink (7 mm fins + chip + pad; ~estimate)
gap      = 6;       // clear gap between the fin tips and the fan underside  (heat_top + gap = 15 mm total)
fx = 0;  fy = 0;    // fan centre relative to the BOARD centre (put it over the SoC heatsink centre)
// -----------------------------------------------------------------------------------------------------------------

post_od  = 6;       // post outside diameter
bore_d   = 2.7;     // M2.5 screw clearance
head_d   = 5.5;     // M2.5 screw head recess in the plate top
head_dep = 1.5;
plate_t  = 4;       // thick enough for the M3 nut pockets under the fan holes
post_h   = heat_top + gap;           // board surface to the underside of the plate

fan       = 40;     // fan frame size (use 30 for a 30 mm fan, with fan_pitch = 24)
fan_pitch = 32;     // fan mounting holes
fan_hole  = 3.2;    // clearance for the fan's M3 machine screws (they come with a hex nut each)
nut_af    = 5.7;    // M3 hex nut across flats (+ a little play)
nut_dep   = 2.6;    // pocket depth under the plate (an M3 nut is 2.4 mm thick)
open_d    = (fan >= 40) ? fan - 2.5 : fan - 4;   // airflow opening: 37.5 mm for a 40 mm fan (keeps a ~1 mm wall to the nut pockets), 26 mm for 30
$fn = 48;

// plate outline = board outline, grown to cover the fan (+ a 2 mm rim) if the fan overhangs
px0 = min(-board/2, fx - fan/2 - 2);  px1 = max(board/2, fx + fan/2 + 2);
py0 = min(-board/2, fy - fan/2 - 2);  py1 = max(board/2, fy + fan/2 + 2);

module corners() { for (sx=[-1,1], sy=[-1,1]) translate([sx*hole_pitch/2, sy*hole_pitch/2, 0]) children(); }

module bracket() {
    difference() {
        union() {
            corners() cylinder(d=post_od, h=post_h + plate_t);
            translate([px0, py0, post_h]) cube([px1 - px0, py1 - py0, plate_t]);
        }
        corners() translate([0,0,-1]) cylinder(d=bore_d, h=post_h + plate_t + 2);               // screw bores
        corners() translate([0,0,post_h + plate_t - head_dep]) cylinder(d=head_d, h=head_dep + 1); // head recesses
        translate([fx, fy, post_h - 1]) cylinder(d=open_d, h=plate_t + 2);                       // airflow opening
        for (sx=[-1,1], sy=[-1,1]) {                                                              // fan screw holes + nut pockets
            translate([fx + sx*fan_pitch/2, fy + sy*fan_pitch/2, post_h - 1]) cylinder(d=fan_hole, h=plate_t + 2);
            translate([fx + sx*fan_pitch/2, fy + sy*fan_pitch/2, post_h - 0.01]) rotate([0, 0, 15*sx*sy]) cylinder(d=nut_af/cos(30), h=nut_dep + 0.01, $fn=6);   // a flat side faces the window
        }
    }
}

module gauge() {
    difference() {
        translate([-board/2, -board/2, 0]) cube([board, board, 1.2]);
        corners() translate([0,0,-1]) cylinder(d=hole_d, h=4);
        translate([fx, fy, -1]) cylinder(d=open_d, h=4);
    }
}

if (part == "gauge") gauge();
else if (flip) translate([0,0,post_h + plate_t]) rotate([180,0,0]) bracket();
else bracket();
