//////////////////////////////////////////////////////////////////////////////////
// Create Date: 10/17/2023 10:05AM by YURONG WU
// Module Name: fir
//////////////////////////////////////////////////////////////////////////////////

module fir
#( parameter pADDR_WIDTH = 12,
   parameter pDATA_WIDTH = 32,
   parameter Tape_Num = 11)
 (
   output wire                     awready,
   output wire                     wready,
   input wire                      awvalid,
   input wire [(pADDR_WIDTH-1):0]  awaddr,
   input wire                      wvalid,
   input wire [(pDATA_WIDTH-1):0]  wdata,
   output wire                     arready,
   input wire                      rready,
   input wire                      arvalid,
   input wire [(pADDR_WIDTH-1):0]  araddr,
   output wire                     rvalid,
   output wire [(pDATA_WIDTH-1):0] rdata,
   input wire                      ss_tvalid,
   input wire [(pDATA_WIDTH-1):0]  ss_tdata,
   input wire                      ss_tlast,
   output wire                     ss_tready,
   input wire                      sm_tready,
   output wire                     sm_tvalid,
   output wire [(pDATA_WIDTH-1):0] sm_tdata,
   output wire                     sm_tlast,
   input wire                      axis_clk,
   input wire                      axis_rst_n,
   
//BRAM for Tap RAM
   output wire [3:0]               tap_WE,
   output wire                     tap_EN,
   output wire [(pDATA_WIDTH-1):0] tap_Di,
   output wire [(pADDR_WIDTH-1):0] tap_A,
   input wire [(pDATA_WIDTH-1):0] tap_Do,
   
//BRAM for Data RAM
   output wire [3:0]               data_WE,
   output wire                     data_EN,
   output wire [(pDATA_WIDTH-1):0] data_Di,
   output wire [(pADDR_WIDTH-1):0] data_A,
   input wire [(pDATA_WIDTH-1):0] data_Do,
   );
   begin
   
   parameter axi_lite_idle = 3'b000;
   parameter axi_lite_write_address = 3'b001;
   parameter axi_lite_read_address = 3'b010;
   parameter axi_lite_write_data = 3'b011;
   parameter axi_lite_read_data = 3'b100;
   
   parameter axi_stream_idle = 2'b00;
   parameter axi_stream_wait_data = 2'b01;
   parameter axi_stream_compute = 2'b10;
   parameter axi_stream_output = 2'b11;
   
   reg [1:0] axi_lite_present_state, axi_lite_next_state;
   reg [1:0] axi_stream_present_state, axi_stream_next_state;
   reg [pDATA_WIDTH-1:0] ap_configuration;
   reg [pDATA_WIDTH-1:0] data_length;
   reg [3:0] compute_count;
   reg [3:0] first_data_shift;
   reg awready_reg;
   reg arready_reg;
   reg rvalid_reg;
   reg wready_reg;
   reg ss_tready_reg;
   reg sm_tvalid_reg;
   reg data_reset_done;
   reg last;
   reg  [(pDATA_WIDTH-1_WIDTH-1):0] fir_result;
   wire [3:0] data_shift;
   
   assign awready = awready_reg;
   assign arready = arready_reg;
   assign rvalid = rvalid_reg;
   assign wready = wready_reg;
   assign ss_tready = ss_tready_reg;
   assign sm_tvalid = sm_tvalid_reg;
   assign sm_tdata = fir_result;
   assign sm_tlast = last;
   assign data_shift = (first_data_shift >= compute_count)? 0 : 11 ;
   
   assign tap_EN = 1;
   assign tap_WE = (axi_lite_present_state == axi_lite_write_data && awaddr == 32'h0020)? 4'b1111:0;
   assign tap_A = (axi_lite_present_state == axi_lite_write_data)? awaddr-32'h0020 : (axi_lite_present_state == axi_lite_read_address && axi_stream_present_state == axi_stream_idle)? araddr-32'h0020 : (compute_count << 2);
   assign tap_Di = wdata;
   
   
   always@(posedge axis_clk or negedge axis_rst_n)begin
     if(!axis_rst_n)begin
	   awready_reg <= 0;
	 end
	 else begin
	 if(axi_lite_present_state == axi_lite_write_address)begin
	   awready_reg <= 1;
     end
	 end
   end
		 
		   
   always@(posedge axis_clk or negedge axis_rst_n)begin
     if(!axis_rst_n)begin
	   arready_reg <= 0;
	 end
	 else begin
	 if(axi_lite_present_state == axi_lite_read_address)begin
	   arready_reg <= 1;
     end
	 end
   end
   
   always@(posedge axis_clk or negedge axis_rst_n)begin
     if(!axis_rst_n)begin
	   rvalid_reg <= 0;
	 end
	 else begin
	 if(axi_lite_present_state == axi_lite_read_data)begin
	   rvalid_reg <= 1;
     end
	 end
   end
   
   always@(posedge axis_clk or negedge axis_rst_n)begin
     if(!axis_rst_n)begin
	   wready_reg <= 0;
	 end
	 else begin
	 if(axi_lite_present_state == axi_lite_write_data)begin
	   wready_reg <= 1;
     end
	 end
   end
   
   assign rdata  = (axi_lite_present_state == axi_lite_read_address) ? (araddr == 32'h0000)? ap_configuration: (araddr == 32'h00010)? data_length : (araddr >= 32'h0020)? tap_Do:0 : 0;
   
   
   always @(posedge  axis_clk or negedge axis_rst_n)begin
     if(!axis_rst_n) begin
	   ap_configuration <= 32'h0000_0004;
       data_length <= 0;
	 end
	 else begin
	 if(axi_lite_present_state == axi_lite_write_data)begin
       if(awaddr == 32'h0000)begin
         ap_configuration <= wdata;
       end
     else if(awaddr == 32'h0010)begin
       data_length <= wdata;
     end
     end
     else if (axi_lite_present_state == axi_lite_read_data)begin
       ap_configuration [1] <= (awaddr == 32'h0000)? 0:ap_configuration[1];
     end
     else begin
       ap_configuration [0] <= (ap_configuration [0] == 0)? 0:1;
       ap_configuration [1] <= (ap_configuration [1] == 1)? 1:0;
       ap_configuration [2] <= (ap_configuration [2] == 1)? 0:1;
     end
     end
	end

    assign data_EN = 1;
    assign data_WE = (axi_stream_present_state == axi_stream_idle)? 4'b1111:0;  
    assign data_A = (axi_stream_present_state == axi_stream_compute)? data_shift  : first_data_shift;
    assign data_Di = (axi_stream_present_state == axi_stream_idle) ? 0:ss_tdata;
	
	
    always@(*)begin
        case(axi_lite_present_state)
            axi_lite_idle:begin
            axi_lite_next_state = (awvalid)? axi_lite_write_address : (arvalid)? axi_lite_read_address :  axi_lite_idle;
            end
            axi_lite_read_address:begin
            axi_lite_next_state = (arvalid && arready)? axi_lite_read_data : axi_lite_read_address;
            end
            axi_lite_read_data:begin
            axi_lite_next_state = (rready && rvalid)? axi_lite_idle : axi_lite_read_data;
            end
            axi_lite_write_address:begin
            axi_lite_next_state = (awvalid && awready)? axi_lite_write_data : axi_lite_write_address; 
            end
            axi_lite_write_data:begin
            axi_lite_next_state = (wready && wvalid)? axi_lite_idle : axi_lite_write_data;
            end
        endcase
    end

    always @(posedge axis_clk, negedge axis_rst_n) begin
      if(!axis_rst_n)begin
        axi_lite_present_state <= axi_lite_idle;
      end
      else begin
        axi_lite_present_state <= axi_lite_next_state;
      end
    end
	
	
    always@(posedge axis_clk, negedge axis_rst_n) begin
		if (!axis_rst_n) begin
            last <= 0;
            compute_count <= 0;
            fir_result <= 0;
		end 
        else begin 
            case(axi_stream_present_state)
                axi_stream_idle:begin
                ss_tready_reg <= 0;
                sm_tvalid_reg <= 0;
                end
                axi_stream_wait_data:begin
                ss_tready_reg <= 1;
                sm_tvalid_reg <= 0;
                compute_count <= 1;
                end
                axi_stream_compute:begin
                ss_tready_reg <= 0;
                sm_tvalid_reg <= (compute_count==11)? 1:0;
                compute_count <= (compute_count==11)? 0 : compute_count+1;
                fir_result <= fir_result + tap_Do * data_Do;
                end
                axi_stream_output:begin
                ss_tready_reg <= 0;
                sm_tvalid_reg <= 0;                   
                fir_result <= 0;
                last <= (ss_tlast==1)? 1:0;
                end
            endcase
		end
	end

    always@(*)begin
        case(axi_stream_present_state)
            axi_stream_idle:begin
             axi_stream_next_state = (ap_configuration [0] == 1)? axi_stream_wait_data:axi_stream_idle;
            end
            axi_stream_wait_data:begin
            axi_stream_next_state = axi_stream_compute;
            end
            axi_stream_compute:begin
            axi_stream_next_state = (fir_compute_count==11)? axi_stream_output:axi_stream_compute;
            end
            axi_stream_output:begin
            axi_stream_next_state = (last_output==1)? axi_stream_idle:axi_stream_wait_data;
            end
        endcase
    end

    always @(posedge axis_clk, negedge axis_rst_n) begin
        if(!axis_rst_n)begin
            axi_stream_present_state <= axi_stream_idle;
        end
        else begin
            axi_stream_present_state <= axi_stream_next_state;
        end
    end
	end
	endmodule
   
   
   
   
   
   
   
   
      
   