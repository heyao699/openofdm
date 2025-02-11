`timescale 1ns/1ps

module dot11_tb;
`include "common_params.v"

reg clock;
reg reset;
reg enable;

reg [10:0] rssi_half_db;
reg[31:0] sample_in;
reg sample_in_strobe;
reg [15:0] clk_count;

wire [31:0] sync_short_metric;
wire short_preamble_detected;
wire power_trigger;

wire [31:0] sync_long_out;
wire sync_long_out_strobe;
wire [31:0] sync_long_metric;
wire sync_long_metric_stb;
wire long_preamble_detected;

wire [31:0] equalizer_out;
wire equalizer_out_strobe;

wire [5:0] demod_out;
wire [5:0] demod_soft_bits;
wire [3:0] demod_soft_bits_pos;
wire demod_out_strobe;

wire [7:0] deinterleave_erase_out;
wire deinterleave_erase_out_strobe;

wire conv_decoder_out;
wire conv_decoder_out_stb;

wire descramble_out;
wire descramble_out_strobe;

wire [3:0] legacy_rate;
wire legacy_sig_rsvd;
wire [11:0] legacy_len;
wire legacy_sig_parity;
wire [5:0] legacy_sig_tail;
wire legacy_sig_stb;
reg signal_done;

wire [3:0] dot11_state;

wire pkt_header_valid_strobe;
wire [7:0] byte_out;
wire byte_out_strobe;
wire [15:0] byte_count_total;
wire [15:0] byte_count;
wire [15:0] pkt_len_total;
wire [15:0] pkt_len;
// wire [63:0] word_out;
// wire word_out_strobe;

reg set_stb;
reg [7:0] set_addr;
reg [31:0] set_data;

wire fcs_out_strobe, fcs_ok;

integer addr;

integer bb_sample_fd;
integer power_trigger_fd;
integer short_preamble_detected_fd;

integer long_preamble_detected_fd;
integer sync_long_metric_fd;
integer sync_long_out_fd;

integer equalizer_out_fd;

integer demod_out_fd;
integer demod_soft_bits_fd;
integer demod_soft_bits_pos_fd;
integer deinterleave_erase_out_fd;
integer conv_out_fd;
integer descramble_out_fd;

integer signal_fd;

integer byte_out_fd;

integer file_i, file_q, file_rssi_half_db, iq_sample_file;

// ONLY allow 100(low FPGA), 200(high FPGA), 240(ultra_scal FPGA) and 400(test)
// do NOT turn on more than one of them
`define CLK_SPEED_100M
//`define CLK_SPEED_200M
//`define CLK_SPEED_240M  
//`define CLK_SPEED_400M

//`define SAMPLE_FILE "../../../../../testing_inputs/simulated/iq_11n_mcs7_gi0_100B_ht_unsupport_openwifi.txt"
//`define SAMPLE_FILE "../../../../../testing_inputs/simulated/iq_11n_mcs7_gi0_100B_wrong_ht_sig_openwifi.txt"
//`define SAMPLE_FILE "../../../../../testing_inputs/simulated/iq_11n_mcs7_gi0_100B_wrong_sig_openwifi.txt"
//`define SAMPLE_FILE "../../../../../testing_inputs/simulated/iq_11n_mcs7_gi0_100B_openwifi.txt"
//`define SAMPLE_FILE "../../../../../testing_inputs/conducted/dot11n_6.5mbps_98_5f_d3_c7_06_27_e8_de_27_90_6e_42_openwifi.txt"
//`define SAMPLE_FILE "../../../../../testing_inputs/conducted/dot11n_52mbps_98_5f_d3_c7_06_27_e8_de_27_90_6e_42_openwifi.txt"
//`define SAMPLE_FILE "../../../../../testing_inputs/radiated/dot11n_19.5mbps_openwifi.txt"
`define SAMPLE_FILE "../../../../../testing_inputs/conducted/dot11n_58.5mbps_98_5f_d3_c7_06_27_e8_de_27_90_6e_42_openwifi.txt"
//`define SAMPLE_FILE "../../../../../testing_inputs/conducted/dot11n_65mbps_98_5f_d3_c7_06_27_e8_de_27_90_6e_42_openwifi.txt" 
//`define SAMPLE_FILE "../../../../../testing_inputs/conducted/dot11a_48mbps_qos_data_e4_90_7e_15_2a_16_e8_de_27_90_6e_42_openwifi.txt"
//`define SAMPLE_FILE "../../../../../testing_inputs/radiated/ack-ok-openwifi.txt"

`define NUM_SAMPLE 118560

//`define SAMPLE_FILE "../../../../../testing_inputs/simulated/openofdm_tx/PL_100Bytes/54Mbps.txt"
//`define NUM_SAMPLE 2048

initial begin
    $dumpfile("dot11.vcd");
    $dumpvars;

    clock = 0;
    reset = 1;
    enable = 0;
    signal_done <= 0;

    # 20 reset = 0;
    enable = 1;

    set_stb = 1;

    # 20
    // do not skip sample
    set_addr = SR_SKIP_SAMPLE;
    set_data = 0;

    # 20 set_stb = 0;
end

integer file_open_trigger = 0;
always @(posedge clock) begin
    file_open_trigger = file_open_trigger + 1;
    if (file_open_trigger==1) begin
        iq_sample_file = $fopen(`SAMPLE_FILE, "r");

        bb_sample_fd = $fopen("./sample_in.txt", "w");
        power_trigger_fd = $fopen("./power_trigger.txt", "w");
        short_preamble_detected_fd = $fopen("./short_preamble_detected.txt", "w");

        sync_long_metric_fd = $fopen("./sync_long_metric.txt", "w");
        long_preamble_detected_fd = $fopen("./sync_long_frame_detected.txt", "w");
        sync_long_out_fd = $fopen("./sync_long_out.txt", "w");

        equalizer_out_fd = $fopen("./equalizer_out.txt", "w");

        demod_out_fd = $fopen("./demod_out.txt", "w");
        demod_soft_bits_fd = $fopen("./demod_soft_bits.txt", "w");
        demod_soft_bits_pos_fd = $fopen("./demod_soft_bits_pos.txt", "w");
        deinterleave_erase_out_fd = $fopen("./deinterleave_erase_out.txt", "w");
        conv_out_fd = $fopen("./conv_out.txt", "w");
        descramble_out_fd = $fopen("./descramble_out.txt", "w");

        signal_fd = $fopen("./signal_out.txt", "w");

        byte_out_fd = $fopen("./byte_out.txt", "w");
    end
end

    always begin
`ifdef CLK_SPEED_100M
        #5 clock = !clock;
`elsif CLK_SPEED_200M
        #2.5 clock = !clock;
`elsif CLK_SPEED_240M
        #2.0833333333 clock = !clock;
`elsif CLK_SPEED_400M
        #1.25 clock = !clock;
`endif
    end

always @(posedge clock) begin
    if (reset) begin
        sample_in <= 0;
        clk_count <= 0;
        sample_in_strobe <= 0;
        addr <= 0;
    end else if (enable) begin
        `ifdef CLK_SPEED_100M
    	if (clk_count == 4) begin  // for 100M; 100/20 = 5
    	`elsif CLK_SPEED_200M
        if (clk_count == 9) begin // for 200M; 200/20 = 10
        `elsif CLK_SPEED_240M
        if (clk_count == 11) begin // for 200M; 240/20 = 12
        `elsif CLK_SPEED_400M
        if (clk_count == 19) begin // for 200M; 400/20 = 20
        `endif
            sample_in_strobe <= 1;
            //$fscanf(iq_sample_file, "%d %d %d", file_i, file_q, file_rssi_half_db);
            $fscanf(iq_sample_file, "%d %d", file_i, file_q);
            sample_in[15:0] <= file_q;
            sample_in[31:16]<= file_i;
            //rssi_half_db <= file_rssi_half_db;
            rssi_half_db <= 0;
            addr <= addr + 1;
            clk_count <= 0;
        end else begin
            sample_in_strobe <= 0;
            clk_count <= clk_count + 1;
        end

        if (legacy_sig_stb) begin
        end

        //if (sample_in_strobe && power_trigger) begin
        if (sample_in_strobe) begin
            $fwrite(bb_sample_fd, "%d %d %d\n", $time/2, $signed(sample_in[31:16]), $signed(sample_in[15:0]));
            $fwrite(power_trigger_fd, "%d %d\n", $time/2, power_trigger);
            $fwrite(short_preamble_detected_fd, "%d %d\n", $time/2, short_preamble_detected);

            $fwrite(long_preamble_detected_fd, "%d %d\n", $time/2, long_preamble_detected);

            $fflush(bb_sample_fd);
            $fflush(power_trigger_fd);
            $fflush(short_preamble_detected_fd);
            $fflush(long_preamble_detected_fd);


            if ((addr % 100) == 0) begin
                $display("%d", addr);
            end

            if (addr == `NUM_SAMPLE) begin
                $fclose(iq_sample_file);

                $fclose(bb_sample_fd);
                $fclose(power_trigger_fd);
                $fclose(short_preamble_detected_fd);

                $fclose(sync_long_metric_fd);
                $fclose(long_preamble_detected_fd);
                $fclose(sync_long_out_fd);

                $fclose(equalizer_out_fd);

                $fclose(demod_out_fd);
                $fclose(demod_soft_bits_fd);
                $fclose(demod_soft_bits_pos_fd);
                $fclose(deinterleave_erase_out_fd);
                $fclose(conv_out_fd);
                $fclose(descramble_out_fd);

                $fclose(signal_fd);
                $fclose(byte_out_fd);
    
                $finish;
            end
        end

        if (sync_long_metric_stb) begin
            $fwrite(sync_long_metric_fd, "%d %d\n", $time/2, sync_long_metric);
            $fflush(sync_long_metric_fd);
        end

        if (sync_long_out_strobe) begin
            $fwrite(sync_long_out_fd, "%d %d\n", $signed(sync_long_out[31:16]), $signed(sync_long_out[15:0]));
            $fflush(sync_long_out_fd);
        end

        if (equalizer_out_strobe) begin
            $fwrite(equalizer_out_fd, "%d %d\n", $signed(equalizer_out[31:16]), $signed(equalizer_out[15:0]));
            $fflush(equalizer_out_fd);
        end

        if (legacy_sig_stb) begin
            signal_done <= 1;
            $fwrite(signal_fd, "%04b %b %012b %b %06b", legacy_rate, legacy_sig_rsvd, legacy_len, legacy_sig_parity, legacy_sig_tail);
            $fflush(signal_fd);
        end

        if ((dot11_state == S_MPDU_DELIM || dot11_state == S_DECODE_DATA || dot11_state == S_MPDU_PAD) && demod_out_strobe) begin
            $fwrite(demod_out_fd, "%b %b %b %b %b %b\n",demod_out[0],demod_out[1],demod_out[2],demod_out[3],demod_out[4],demod_out[5]);
            $fwrite(demod_soft_bits_fd, "%b %b %b %b %b %b\n",demod_soft_bits[0],demod_soft_bits[1],demod_soft_bits[2],demod_soft_bits[3],demod_soft_bits[4],demod_soft_bits[5]);
            $fwrite(demod_soft_bits_pos_fd, "%b %b %b %b\n",demod_soft_bits_pos[0],demod_soft_bits_pos[1],demod_soft_bits_pos[2],demod_soft_bits_pos[3]);
            $fflush(demod_out_fd);
            $fflush(demod_soft_bits_fd);
            $fflush(demod_soft_bits_pos_fd);
        end

        if ((dot11_state == S_MPDU_DELIM || dot11_state == S_DECODE_DATA || dot11_state == S_MPDU_PAD) && deinterleave_erase_out_strobe) begin
            $fwrite(deinterleave_erase_out_fd, "%b %b %b %b %b %b %b %b\n", deinterleave_erase_out[0], deinterleave_erase_out[1], deinterleave_erase_out[2],  deinterleave_erase_out[3], deinterleave_erase_out[4], deinterleave_erase_out[5], deinterleave_erase_out[6],  deinterleave_erase_out[7]);
            $fflush(deinterleave_erase_out_fd);
        end

        if ((dot11_state == S_MPDU_DELIM || dot11_state == S_DECODE_DATA || dot11_state == S_MPDU_PAD) && conv_decoder_out_stb) begin
            $fwrite(conv_out_fd, "%b\n", conv_decoder_out);
            $fflush(conv_out_fd);
        end

        if ((dot11_state == S_MPDU_DELIM || dot11_state == S_DECODE_DATA || dot11_state == S_MPDU_PAD) && descramble_out_strobe) begin
            $fwrite(descramble_out_fd, "%b\n", descramble_out);
            $fflush(descramble_out_fd);
        end

        if ((dot11_state == S_MPDU_DELIM || dot11_state == S_DECODE_DATA || dot11_state == S_MPDU_PAD) && byte_out_strobe) begin
            $fwrite(byte_out_fd, "%02x\n", byte_out);
            $fflush(byte_out_fd);
        end

    end
end

dot11 dot11_inst (
    .clock(clock),
    .enable(enable),
    .reset(reset),

    //.set_stb(set_stb),
    //.set_addr(set_addr),
    //.set_data(set_data),

    .power_thres(11'd0),
    .min_plateau(32'd100),

    .rssi_half_db(rssi_half_db),
    .sample_in(sample_in),
    .sample_in_strobe(sample_in_strobe),
    .soft_decoding(1'b1),

    .pkt_header_valid_strobe(pkt_header_valid_strobe),
    .pkt_len(pkt_len),
    .pkt_len_total(pkt_len_total),
    .byte_out_strobe(byte_out_strobe),
    .byte_out(byte_out),
    .byte_count_total(byte_count_total),
    .byte_count(byte_count),
    .fcs_out_strobe(fcs_out_strobe),
    .fcs_ok(fcs_ok),

    .state(dot11_state),

    .power_trigger(power_trigger),

    .short_preamble_detected(short_preamble_detected),

    .sync_long_metric(sync_long_metric),
    .sync_long_metric_stb(sync_long_metric_stb),
    .long_preamble_detected(long_preamble_detected),
    .sync_long_out(sync_long_out),
    .sync_long_out_strobe(sync_long_out_strobe),

    .equalizer_out(equalizer_out),
    .equalizer_out_strobe(equalizer_out_strobe),

    .legacy_sig_stb(legacy_sig_stb),
    .legacy_rate(legacy_rate),
    .legacy_sig_rsvd(legacy_sig_rsvd),
    .legacy_len(legacy_len),
    .legacy_sig_parity(legacy_sig_parity),
    .legacy_sig_tail(legacy_sig_tail),

    .demod_out(demod_out),
    .demod_soft_bits(demod_soft_bits),
    .demod_soft_bits_pos(demod_soft_bits_pos),
    .demod_out_strobe(demod_out_strobe),

    .deinterleave_erase_out(deinterleave_erase_out),
    .deinterleave_erase_out_strobe(deinterleave_erase_out_strobe),

    .conv_decoder_out(conv_decoder_out),
    .conv_decoder_out_stb(conv_decoder_out_stb),

    .descramble_out(descramble_out),
    .descramble_out_strobe(descramble_out_strobe)
);

/*
byte_to_word_fcs_sn_insert byte_to_word_fcs_sn_insert_inst (
    .clk(clock),
    .rstn((~reset)&(~pkt_header_valid_strobe)),

    .byte_in(byte_out),
    .byte_in_strobe(byte_out_strobe),
    .byte_count(byte_count),
    .num_byte(pkt_len),
    .fcs_in_strobe(fcs_out_strobe),
    .fcs_ok(fcs_ok),
    .rx_pkt_sn_plus_one(0),

    .word_out(word_out),
    .word_out_strobe(word_out_strobe)
);
*/

endmodule
