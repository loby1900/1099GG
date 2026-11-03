# Android / touch controls

The gameplay HUD adds touch controls automatically on touch devices. The left virtual stick steers; the right-side green and red pads accelerate and brake/reverse. The smaller `+` and `-` pads shift gears. Desktop keyboard/controller actions remain unchanged.

To preview the touch layout in the editor, select the HUD node and enable `force_mobile_controls` in the Inspector. The HUD needs to cover the game viewport so its touch coordinates and controls line up with the screen.

The controls emit the existing Godot actions (`ui_left`, `ui_right`, `ui_up`, `ui_down`, `shift_up`, and `shift_down`) so the car can keep using its existing input system. Test on an Android export: touch simulation in the editor does not replace a real multi-touch device test.
