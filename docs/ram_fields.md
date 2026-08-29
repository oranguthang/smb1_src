# RAM Fields

This registry records high-confidence semantic RAM aliases for the selected
reference revision. Addresses are CPU RAM addresses; array aliases may use an
object-slot index at the access site.

## Player Input and State

| Symbol | Address | Role |
| --- | ---: | --- |
| `ram_saved_joypad_bits` | `$06FC` | Active player's current or scripted controller byte |
| `ram_a_b_buttons` | `$000A` | Current A/B button subset |
| `ram_up_down_buttons` | `$000B` | Current up/down subset |
| `ram_left_right_buttons` | `$000C` | Current left/right subset |
| `ram_previous_a_b_buttons` | `$000D` | Prior-frame A/B subset for edge detection |
| `ram_player_state` | `$001D` | Movement state: ground, jump/swim, fall, or climb |
| `ram_player_facing_dir` | `$0033` | Facing bit used by rendering, friction, and climbing |
| `ram_player_moving_dir` | `$0045` | Direction derived from signed horizontal speed |
| `ram_crouching_flag` | `$0714` | Nonzero while big player crouches on the ground |
| `ram_swimming_flag` | `$0704` | Selects water movement and jump profiles |
| `ram_player_collision_bits` | `$0490` | Direction mask retained by background collision probes |

## Horizontal Motion

| Symbol | Address | Role |
| --- | ---: | --- |
| `ram_player_page_loc` | `$006D` | Horizontal world page |
| `ram_player_x_position` | `$0086` | Horizontal pixel within the page |
| `ram_player_x_speed` | `$0057` | Signed horizontal speed used by position integration |
| `ram_player_x_speed_fraction` | `$0705` | Fractional horizontal velocity accumulator |
| `ram_player_x_speed_absolute` | `$0700` | Absolute horizontal speed used for profiles and animation |
| `ram_player_friction_high` | `$0701` | Signed high byte of the selected friction increment |
| `ram_player_friction_low` | `$0702` | Low byte of the selected friction increment |
| `ram_player_maximum_left_speed` | `$0450` | Current signed left speed limit |
| `ram_player_maximum_right_speed` | `$0456` | Current right speed limit |
| `ram_running_speed` | `$0703` | Nonzero fast-running value used by profile selection |
| `ram_running_timer` | `$0783` | Short B-button running latch |

## Vertical Motion

| Symbol | Address | Role |
| --- | ---: | --- |
| `ram_player_y_high_pos` | `$00B5` | Vertical page/high coordinate |
| `ram_player_y_position` | `$00CE` | Vertical pixel/low coordinate |
| `ram_player_y_position_fraction` | `$0416` | Fractional vertical position accumulator |
| `ram_player_y_speed` | `$009F` | Signed vertical speed byte |
| `ram_player_y_speed_fraction` | `$0433` | Fractional vertical velocity byte |
| `ram_player_active_gravity` | `$0709` | Gravity currently applied by player integration |
| `ram_player_fall_gravity` | `$070A` | Gravity selected after jump release or while falling |
| `ram_jump_origin_y_high_pos` | `$0707` | Vertical page captured at jump initialization |
| `ram_jump_origin_y_position` | `$0708` | Vertical pixel captured at jump initialization |
| `ram_jump_release_min_displacement` | `$0706` | Minimum upward displacement before release cuts the jump |

## Animation and Special Movement

| Symbol | Address | Role |
| --- | ---: | --- |
| `ram_player_anim_timer` | `$0781` | Active animation countdown |
| `ram_player_anim_timer_reload` | `$070C` | Reload selected from horizontal speed or climbing direction |
| `ram_jumpspring_anim_ctrl` | `$070E` | handler_draw_jumpspring animation state that gates ordinary integration |
| `ram_climb_side_timer` | `$0789` | Delay before changing sides of a vine |

## Object and OAM Allocation

| Symbol | Address | Role |
| --- | ---: | --- |
| `ram_block_object_slot` | `$03EE` | Alternating zero/one selector for block state, position, and shared OAM arrays |
| `ram_block_spr_data_offset` | `$06EC` | Two shuffled OAM offsets assigned to the block object slots |
| `ram_alt_spr_data_offset` | `$06EC` | Semantic alias for fireball explosions and floating scores reusing those OAM regions |

These roles are `!(OBS)` observations from direct reads, writes, and arithmetic
in the movement and collision modules. Broader RAM documentation will extend
this registry during milestone 5.
