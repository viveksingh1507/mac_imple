module xgspon_activation_timers(
    input wire clk, input wire rst_n,
    input wire start_sn, input wire start_ranging, input wire start_ploam, input wire start_sync, input wire start_popup,
    input wire clear_sn, input wire clear_ranging, input wire clear_ploam, input wire clear_sync, input wire clear_popup,
    output reg sn_timeout, output reg ranging_timeout, output reg ploam_timeout, output reg sync_timeout, output reg popup_timeout
);
    parameter SN_LIMIT=1024, RANGING_LIMIT=2048, PLOAM_LIMIT=4096, SYNC_LIMIT=4096, POPUP_LIMIT=2048;
    reg [15:0] sn_cnt, ranging_cnt, ploam_cnt, sync_cnt, popup_cnt;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin sn_cnt<=0; ranging_cnt<=0; ploam_cnt<=0; sync_cnt<=0; popup_cnt<=0; sn_timeout<=0; ranging_timeout<=0; ploam_timeout<=0; sync_timeout<=0; popup_timeout<=0; end
        else begin
            if(clear_sn) begin sn_cnt<=0; sn_timeout<=0; end else if(start_sn && !sn_timeout) begin if(sn_cnt>=SN_LIMIT) sn_timeout<=1; else sn_cnt<=sn_cnt+1; end
            if(clear_ranging) begin ranging_cnt<=0; ranging_timeout<=0; end else if(start_ranging && !ranging_timeout) begin if(ranging_cnt>=RANGING_LIMIT) ranging_timeout<=1; else ranging_cnt<=ranging_cnt+1; end
            if(clear_ploam) begin ploam_cnt<=0; ploam_timeout<=0; end else if(start_ploam && !ploam_timeout) begin if(ploam_cnt>=PLOAM_LIMIT) ploam_timeout<=1; else ploam_cnt<=ploam_cnt+1; end
            if(clear_sync) begin sync_cnt<=0; sync_timeout<=0; end else if(start_sync && !sync_timeout) begin if(sync_cnt>=SYNC_LIMIT) sync_timeout<=1; else sync_cnt<=sync_cnt+1; end
            if(clear_popup) begin popup_cnt<=0; popup_timeout<=0; end else if(start_popup && !popup_timeout) begin if(popup_cnt>=POPUP_LIMIT) popup_timeout<=1; else popup_cnt<=popup_cnt+1; end
        end
    end
endmodule
