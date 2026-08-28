; NES specific hardware defines

PPU_CTRL_REG1         = $2000
PPU_CTRL_REG2         = $2001
PPU_STATUS            = $2002
PPU_SPR_ADDR          = $2003
PPU_SPR_DATA          = $2004
PPU_SCROLL_REG        = $2005
PPU_ADDRESS           = $2006
PPU_DATA              = $2007

PPU_NAMETABLE_0       = $2000
PPU_NAMETABLE_1       = $2400

SND_REGISTER          = $4000
SND_SQUARE1_REG       = $4000
SND_SQUARE2_REG       = $4004
SND_TRIANGLE_REG      = $4008
SND_NOISE_REG         = $400c
SND_DELTA_REG         = $4010
SND_MASTERCTRL_REG    = $4015

SPR_DMA               = $4014
JOYPAD_PORT           = $4016
JOYPAD_PORT1          = $4016
JOYPAD_PORT2          = $4017

VS_STATUS             = $4016
VS_REQUEST            = $4016
VS_STATUS2            = $4017
VS_COIN_COUNTER       = $4020

FDS_CONTROL           = $4025
FDS_TIMER_DATA_LO     = $4020
FDS_TIMER_DATA_HI     = $4021
FDS_TIMER_CONTROL     = $4022
FDS_MEDIA_STATUS      = $4030

con_fds_control_motor_on       = %00000001
con_fds_control_transfer_reset = %00000010
con_fds_control_read_mode      = %00000100
con_fds_control_io_mask        = %00100000
con_fds_timer_irq_enable       = %00000010
con_fds_media_timer_irq        = %00000001
con_fds_media_transfer         = %00000010
con_fds_irq_mode_game          = %11000000
con_fds_nmi_split_timer        = 5720

sub_fds_bios_delay_short = $e149
