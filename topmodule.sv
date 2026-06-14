`timescale 1ns/1ps
module Pc (
	input clk,
	input reset,
	input branch,
	input stall,
	input [31:0] next_pc,
	input ecall_sig,
	output  reg [31:0] pc
);
	always @(posedge clk or posedge reset) begin

		if(reset) 
			pc <= 0;
		else begin
			if(stall)
				pc <= pc;
			else if (branch)
				pc <= next_pc;
			else if (ecall_sig)
				pc <= pc;
			else 
				pc <= pc+4;
		end
	end
endmodule


module Register_file(
	input reg_w,
	input clk,
	input [4:0] reg_1,
	input [4:0] reg_2,
	input [4:0] reg_write,
	input [31:0] reg_w_data,
	output wire [31:0] reg_1_data,
	output wire [31:0] reg_2_data
);
	reg [31:0] reg_file [0:31];
	assign reg_1_data = (reg_w && (reg_write == reg_1) && (reg_1 != 5'd0)) ? reg_w_data : reg_file[reg_1];
	assign reg_2_data = (reg_w && (reg_write == reg_2) && (reg_2 != 5'd0)) ? reg_w_data : reg_file[reg_2];

    // Synchronous write on positive edge
    always @(posedge clk) begin
        reg_file[0] <= 32'b0; // Ensure x0 stays zero
        if(reg_w && (reg_write != 5'd0)) begin
            reg_file[reg_write] <= reg_w_data; 
        end
    end
endmodule


module Alu_MUX(
	input [31:0] rs_2,
	input [31:0] imm_gen,
	input imm,
	output reg[31:0] sel
);
	always@(*)begin
		case(imm)
			1'b1: sel = imm_gen;
			1'b0: sel = rs_2;
		endcase
	end
endmodule


module Alu(
	input [31:0] reg_1_data,
	input [31:0] reg_2_data,
	input [3:0]operation_type, // AND,OR,ADD,SUB,SLL,SRL,SRA,XOR
	output reg [31:0]ALU_result
);
	always@(*) begin
		case(operation_type)
			4'b0000 : ALU_result = reg_1_data & reg_2_data;
			4'b0001 : ALU_result = reg_1_data | reg_2_data;
			4'b0010 : ALU_result = reg_1_data + reg_2_data;
			4'b0011 : ALU_result = reg_1_data + 32'd1 + ~(reg_2_data);
			4'b0100 : ALU_result = reg_1_data << reg_2_data[4:0];//for the sake of synthesis tools to not bomb
			4'b0101 : ALU_result = reg_1_data >> reg_2_data[4:0];
			4'b0110 : ALU_result = $signed(reg_1_data) >>> reg_2_data[4:0];
			4'b0111 : ALU_result = reg_1_data ^ reg_2_data;
			4'b1000 : ALU_result = (reg_1_data == reg_2_data) ? 1 : 0;
			4'b1010 : ALU_result = (reg_1_data >= reg_2_data) ? 1 : 0;
			4'b1011 : ALU_result = (reg_1_data < reg_2_data) ? 1 : 0;
			4'b1100 : ALU_result = ($signed(reg_1_data) < $signed(reg_2_data)) ? 1 : 0;
			4'b1101 : ALU_result = ($signed(reg_1_data) >= $signed(reg_2_data)) ? 1 : 0;
			4'b1110 : ALU_result = (reg_1_data != reg_2_data) ? 1 : 0;
			default : ALU_result = 32'b0;
		endcase
	end
endmodule
// ALU is just a for calculations
// so let me have a signal to differentitate between different purposes ALU is
// going to be use for
module Id(
	input clk,
	input [31:0] inst,
	output wire [4:0]rd,
	output wire [4:0]rs1,
	output wire [4:0]rs2,
	output reg [31:0]imm_gen,
	output reg imm,
	output reg [1:0]reg_w_id,
	output reg [3:0]ALU_mux,
	output wire [2:0] func3,// to identify how many bits to load or store
	output wire [6:0] opcode,//to use it for branch , jal , jalr , load, store differentiation.
	output wire id_ecall_or_ebreak
		
);
	wire [6:0]func7;
	assign opcode = inst[6:0];
	assign rd  = inst[11:7];
	assign func3 = inst[14:12];
	assign rs1 = inst[19:15];
	assign rs2 = inst[24:20];
	assign func7 = inst[31:25];
	wire [11:0] test = inst[31:20];
	wire is_system = (opcode == 7'b1110011);
	assign id_ecall_or_ebreak = is_system && (test == 12'h000 || test == 12'h001);
	always@(*) begin
		imm = 1'b0;
		imm_gen = 32'd0;
		ALU_mux = 4'b1111;
		reg_w_id = 2'b00;
		case(opcode)
			7'b0110011 :begin //R 
				reg_w_id = 2'b11;
				case(func7)
					7'h00:
						case(func3)
							3'h0: ALU_mux = 4'b0010;
							3'h4: ALU_mux = 4'b0111;
							3'h6: ALU_mux = 4'b0001;
							3'h7: ALU_mux = 4'b0000;
							3'h1: ALU_mux = 4'b0100;
							3'h5: ALU_mux = 4'b0101;
							3'h2: ALU_mux = 4'b1100;
							3'h3: ALU_mux = 4'b1011;
							default: ALU_mux = 4'b1111; //invalid
						endcase
					7'h20:
						case(func3)
							3'h0: ALU_mux = 4'b0011;
							3'h5: ALU_mux = 4'b0110;
							default: ALU_mux = 4'b1111;
						endcase
					default: ALU_mux = 4'b1111 ;//invalid
				endcase
			end
			7'b0010011: begin//I
				reg_w_id = 2'b11;			
				imm = 1'b1;
				case(func3)
					3'h0:begin 
						ALU_mux = 4'b0010;
						imm_gen = {{20{inst[31]}},inst[31:20]};
					end
					3'h4:begin 
						ALU_mux = 4'b0111;
						imm_gen = {{20{inst[31]}},inst[31:20]};
					end
					3'h6:begin  
						ALU_mux = 4'b0001;
						imm_gen = {{20{inst[31]}},inst[31:20]};
					end
					3'h7:begin 
						ALU_mux = 4'b0000;
						imm_gen = {{20{inst[31]}},inst[31:20]};end
					3'h1:begin 
						ALU_mux = 4'b0100;
						imm_gen = {27'd0,inst[24:20]};end
					3'h5:begin 
						imm_gen = {27'd0,inst[24:20]};
						case(inst[31:25])
							7'h00: ALU_mux = 4'b0101;
							7'h20: ALU_mux = 4'b0110;
							default: ALU_mux = 4'b1111;
						endcase 
					end
					3'h2:begin
						imm_gen = {{20{inst[31]}},inst[31:20]};
						ALU_mux = 4'b1100;
					end
					3'h3:begin
						imm_gen = {{20{inst[31]}},inst[31:20]};
						ALU_mux = 4'b1011;
					end
					default: ALU_mux = 4'b1111; //invalid
				endcase
			end
			7'b0000011:begin//L
				reg_w_id = 2'b10;					
				ALU_mux = 4'b0010;
				imm = 1'b1;
				imm_gen = {{20{inst[31]}},inst[31:20]};
			end
			7'b0100011:begin//S
				reg_w_id = 2'b00;
				imm = 1'b1;
				ALU_mux = 4'b0010;
				imm_gen = {{20{inst[31]}},inst[31:25],inst[11:7]};
			end
			7'b1100011: begin
				reg_w_id = 2'b00;
				case(func3)//B-type
					3'h0: begin	
						imm_gen = {{19{inst[31]}},inst[31:31],inst[7:7],inst[30:25],inst[11:8],1'b0};
						ALU_mux = 4'b1000;
					end
					3'h1:begin	
						imm_gen = {{19{inst[31]}},inst[31:31],inst[7:7],inst[30:25],inst[11:8],1'b0};
						ALU_mux = 4'b1110;
					end 
					3'h4:begin	
						imm_gen = {{19{inst[31]}},inst[31:31],inst[7:7],inst[30:25],inst[11:8],1'b0};
						ALU_mux = 4'b1100; 
					end
					3'h5:begin	
						imm_gen = {{19{inst[31]}},inst[31:31],inst[7:7],inst[30:25],inst[11:8],1'b0};
						ALU_mux = 4'b1101;
					end
					3'h6:begin	
						imm_gen = {{19{inst[31]}},inst[31:31],inst[7:7],inst[30:25],inst[11:8],1'b0};
						ALU_mux = 4'b1011;
					end
					3'h7:begin	
						imm_gen = {{19{inst[31]}},inst[31:31],inst[7:7],inst[30:25],inst[11:8],1'b0};
						ALU_mux = 4'b1010;
					end				
					default:ALU_mux = 4'b1111;
				endcase
			end
			7'b1101111:begin//jal
				reg_w_id = 2'b11;
				imm = 1'b0;
				imm_gen = {{11{inst[31]}},inst[31:31],inst[19:12],inst[20:20],inst[30:21],1'b0};
				ALU_mux = 4'b0010;
			end
			7'b1100111:begin//jalr
				reg_w_id = 2'b11;	
				imm = 1'b0;
				ALU_mux = 4'b0010;
				imm_gen = {{20{inst[31]}},inst[31:20]};
			end
			7'b0110111:begin//lui
				reg_w_id = 2'b11;
				imm_gen = {inst[31:12],12'd0};
				ALU_mux = 4'b0010;
				imm = 1'b1;
			end
			7'b0010111:begin//auipc
				reg_w_id = 2'b11;
				imm_gen = {inst[31:12],12'd0};
				ALU_mux = 4'b0010;
				imm = 1'b1;
			end
			default:begin	
				imm = 1'b0;
				imm_gen = 32'd0;
				ALU_mux = 4'b1111;
				reg_w_id = 2'b00;
			end
		endcase
	end

endmodule
//RISCV is little endian 

module Inst_mem(
	input [31:0]pc,
	output reg [31:0] inst
	);
	reg [7:0] imem [0:16383];//16KB imem
	initial begin// for inputting
        $readmemh("program.hex", imem);
	end
	always@(*) begin
		inst = {imem[pc+3],imem[pc+2],imem[pc+1],imem[pc]};	
	end
endmodule


module Data_mem(
	input clk,
	input [31:0]address,
	input [6:0] opcode,
	input [2:0]func3,
	input [31:0]rs2,
	output reg [31:0] reg_w_data
);
	reg [7:0] dmem [0:16383];//16KB dmem
integer i;
	initial begin
		for(i = 0;i < 16383; i = i+1)
			dmem[i] = 8'h00;
	end
	initial begin//for inputting
       $readmemh("data.hex", dmem);
    end
// Fix: Put both read and write inside the clocked block
	always @(posedge clk) begin
		// 1. Handle Writes (Stores)
		if (opcode == 7'b0100011) begin
			case(func3)
				3'h0: dmem[address] <= rs2[7:0];
				3'h1: {dmem[address+1], dmem[address]} <= rs2[15:0];
				3'h2: {dmem[address+3], dmem[address+2], dmem[address+1], dmem[address]} <= rs2[31:0];
				default: ;
			endcase
		end

		// 2. Handle Reads (Loads) - Now synchronous!
		// This updates the read data cleanly on the clock edge, matching hardware BRAM behavior.
		if (opcode == 7'b0000011) begin
			case(func3)
				3'h0: reg_w_data <= {{24{dmem[address][7]}}, dmem[address]};
				3'h1: reg_w_data <= {{16{dmem[address+1][7]}}, dmem[address+1], dmem[address]};
				3'h2: reg_w_data <= {dmem[address+3], dmem[address+2], dmem[address+1], dmem[address]};
				3'h4: reg_w_data <= {24'd0, dmem[address]};
				3'h5: reg_w_data <= {16'd0, dmem[address+1], dmem[address]};
				default: reg_w_data <= 32'd0;
			endcase
		end else begin
			reg_w_data <= 32'd0;
		end
	end
endmodule


module wb (
	input [6:0] opcode,
	input [31:0] ALU_result,
	input [31:0] reg_w_data_dmem,
	input [1:0]reg_w_id,
	input [31:0] pc,
	input [31:0] imm_gen, 
	output reg reg_w,
	output reg[31:0] reg_w_data
);
	always@(*) begin
		reg_w      = reg_w_id[1];
        reg_w_data = 32'd0;
		case(opcode)//branch,jal,jalr,rtype,itype,s and l
			7'b0110011:begin//R
				reg_w_data = ALU_result;
			end
			7'b0010011:begin//I
				reg_w_data = ALU_result;
			end
			7'b0000011:begin//L
				reg_w_data = reg_w_data_dmem;
			end
			7'b0100011:begin//S
				reg_w_data = 32'd0;
			end
			7'b1100011: begin//B
				reg_w_data = 32'd0;
			end	
			7'b1101111:begin//jal 
				reg_w_data = ALU_result;//pc + 4;
			end
			7'b1100111:begin//jalr
				reg_w_data = ALU_result;//pc + 4;
			end
			7'b0110111:begin//lui
				reg_w_data = ALU_result;//imm_gen;
			end
			7'b0010111:begin//auipc
				reg_w_data = ALU_result;//pc + imm_gen;
			end
			default: begin
				reg_w = 1'b0;
				reg_w_data = 32'd0;
			end
		endcase
	end
endmodule

module topmodule(input clk,input reset,output wire [31:0] current_inst_debug,output wire [31:0] current_pc_debug,output sim_halt);//core
	typedef struct packed{
		logic [31:0]pc;
		logic [31:0]inst;

	}if_id_l;

	typedef struct packed{
		logic [31:0] pc;
		logic [31:0] imm_gen;
		logic imm;
		logic [3:0] ALU_mux;
		logic [2:0] func3;
		logic [6:0] opcode;
		logic [1:0]reg_w_id;
		logic [4:0] rd;
		logic [4:0] rs1;
		logic [4:0] rs2;// check if hazard happening
		logic [31:0] reg_1_data;
		logic [31:0] reg_2_data;
		logic id_ex_ecall;
		//will figure out reg_w later
	}id_ex_l;

	typedef struct packed{
		logic [31:0] pc;
		logic [1:0]reg_w_alu;
		logic [31:0]ALU_result;
		logic [31:0]imm_gen;
		logic [6:0] opcode;
		logic [2:0] func3;
		logic [31:0] rs2;
		logic [4:0] rs2_add;
		logic [4:0] rd;
		logic ex_mem_ecall;
	}ex_mem_l;

	typedef struct packed{
		logic [31:0] pc;
		logic [1:0]reg_w_mem;
		logic [4:0] rd;
		logic [31:0]imm_gen;
		logic [31:0] ALU_result;
		logic [6:0] opcode;
		logic mem_wb_ecall;
	}mem_wb_l;
	// Instantiate the in and out part of the latches.
	if_id_l  if_id_in,  if_id_out;
	id_ex_l  id_ex_in,  id_ex_out;
	ex_mem_l ex_mem_in, ex_mem_out;
	mem_wb_l mem_wb_in, mem_wb_out;


	always @(posedge clk or posedge reset) begin
		if (reset) begin
			if_id_out  <= '0;
			id_ex_out  <= '0;
			ex_mem_out <= '0;
			mem_wb_out <= '0;
		end else begin
				if(stall)begin
					if_id_out <= if_id_out;
					id_ex_out <= '0;
					ex_mem_out <= ex_mem_in;
					mem_wb_out <= mem_wb_in;
				end
				else if (branch_taken) begin
					// Flush instructions in Fetch and Decode stages
					if_id_out  <= '0;
					id_ex_out  <= '0; 
					ex_mem_out <= ex_mem_in;
					mem_wb_out <= mem_wb_in;
				end else if (ecall) begin
					if_id_out <= if_id_out;
					id_ex_out <= id_ex_in;
					ex_mem_out <= ex_mem_in;
					mem_wb_out <= mem_wb_in;
				end else begin
					if_id_out  <= if_id_in;
					id_ex_out  <= id_ex_in;
					ex_mem_out <= ex_mem_in;
					mem_wb_out <= mem_wb_in;
				end

		end	
	end
	

	wire [31:0]pc;
	reg stall;
	wire [31:0]inst;
	wire [4:0]rd;
	wire [4:0]rs1;
	wire [4:0]rs2;
	wire [31:0]imm_gen;
	wire imm;
	wire [3:0]ALU_mux;
	wire [2:0]func3;
	wire [6:0]opcode;
	wire [31:0]reg_1_data;
	wire [31:0]reg_2_data;
	wire [31:0]sel;
	wire [31:0]ALU_result;
	wire [31:0]reg_w_data_dmem;
	wire [1:0]reg_w_id;
	wire reg_w;
	wire [31:0]reg_w_data;
	wire branch_taken;
	wire [31:0]branch_target;
	wire ecall;
	reg [31:0]jalr_reg_1;

	Pc pc1 (.clk(clk),.reset(reset),.branch(branch_taken),.next_pc(branch_target),.pc(pc),.stall(stall),.ecall_sig(ecall));
	Inst_mem imem1 (.pc(pc) ,.inst(inst));
	always@(*)begin
		if_id_in.pc = pc;
		if_id_in.inst = inst;
	end
	Id id1(.clk(clk),.inst(if_id_out.inst),.rd(rd),.rs1(rs1),.rs2(rs2),.imm_gen(imm_gen),.imm(imm),.ALU_mux(ALU_mux),.func3(func3),.opcode(opcode),.reg_w_id(reg_w_id),.id_ecall_or_ebreak(ecall));
	
	wire [31:0]pc_id;
	assign pc_id = if_id_out.pc;
	
	Register_file regfile1(.reg_w(reg_w), .clk(clk),.reg_1(rs1),.reg_2(rs2),.reg_write(mem_wb_out.rd),.reg_w_data(reg_w_data),.reg_1_data(reg_1_data),.reg_2_data(reg_2_data));
	
	always@(*)begin
		id_ex_in.pc = pc_id;
		id_ex_in.imm_gen = imm_gen;
		id_ex_in.imm = imm;
		id_ex_in.ALU_mux = ALU_mux;
		id_ex_in.func3 = func3;
		id_ex_in.opcode = opcode;
		id_ex_in.rd = rd;
		id_ex_in.rs1 = rs1;
		id_ex_in.rs2 = rs2;
		id_ex_in.reg_1_data = reg_1_data;
		id_ex_in.reg_2_data = reg_2_data;
		id_ex_in.reg_w_id = reg_w_id;
		id_ex_in.id_ex_ecall = ecall;
	end
	Alu_MUX alu_mux1(.rs_2(forwarded_reg_2),.imm_gen(id_ex_out.imm_gen),.imm(id_ex_out.imm),.sel(sel));
	
	// Changed from wire to reg
	reg [31:0] rs1_ex;
	reg [31:0] pc_ex;
	reg [4:0]  rd_ex;
	reg [1:0]reg_w_ex;
	reg [4:0]  r_s1_ex;
	reg [4:0]  r_s2_ex;
	reg [31:0] rs2_ex;
	reg [6:0]  opcode_ex;
	reg [2:0]  func3_ex;
	reg [31:0] imm_gen_ex;
	reg ecall_ex;
	// Changed from continuous assign to combinational always block with =
	always @(*) begin
		pc_ex      = id_ex_out.pc;
		rd_ex      = id_ex_out.rd;
		r_s1_ex    = id_ex_out.rs1;
		r_s2_ex    = id_ex_out.rs2;
		rs1_ex     = id_ex_out.reg_1_data;
		rs2_ex     = id_ex_out.reg_2_data;
		opcode_ex  = id_ex_out.opcode;
		func3_ex   = id_ex_out.func3;
		reg_w_ex   = id_ex_out.reg_w_id;
		imm_gen_ex = id_ex_out.imm_gen;
		ecall_ex = id_ex_out.id_ex_ecall;
	end
	
	Alu alu1(.reg_1_data(forwarded_reg_1),.reg_2_data(sel),.operation_type(id_ex_out.ALU_mux),.ALU_result(ALU_result));
	// Combinational Branch/Jump Resolution Logic in EX Stage
    reg ex_branch_taken;
    reg [31:0] ex_branch_target;

    always @(*) begin
        ex_branch_taken  = 1'b0;
        ex_branch_target = 32'd0;

        case(opcode_ex)
            7'b1100011: begin // B-type (Branch)
                if (ALU_result[0] == 1'b1) begin // Condition met
                    ex_branch_taken  = 1'b1;
                    ex_branch_target = id_ex_out.pc + id_ex_out.imm_gen;
                end
            end
            7'b1101111: begin // JAL
                ex_branch_taken  = 1'b1;
                ex_branch_target = id_ex_out.pc + id_ex_out.imm_gen;
			end
            7'b1100111: begin // JALR
                ex_branch_taken  = 1'b1;
                ex_branch_target =  jalr_reg_1 + id_ex_out.imm_gen;
			end
			default: ;
		endcase
    end

    assign branch_taken  = ex_branch_taken;
    assign branch_target = ex_branch_target;

	always@(*)begin
		ex_mem_in.pc = pc_ex;
		ex_mem_in.ALU_result = ALU_result;
		ex_mem_in.opcode = opcode_ex;
		ex_mem_in.func3 = func3_ex;
		ex_mem_in.rs2 = forwarded_reg_2;
		ex_mem_in.rd = rd_ex;
		ex_mem_in.imm_gen = imm_gen_ex;
		ex_mem_in.reg_w_alu = reg_w_ex;
		ex_mem_in.rs2_add = r_s2_ex;
		ex_mem_in.ex_mem_ecall = ecall_ex;
	end

	wire [31:0]pc_mem;
	assign pc_mem = ex_mem_out.pc;
	wire [4:0]rd_mem;
	assign rd_mem = ex_mem_out.rd;
	wire [6:0]opcode_mem;
	assign opcode_mem = ex_mem_out.opcode;
	wire [31:0]ALU_result_mem;
	assign ALU_result_mem = ex_mem_out.ALU_result;
	wire [31:0]imm_gen_mem;
	assign imm_gen_mem = ex_mem_out.imm_gen;
	wire [1:0]reg_w_mem;
	assign reg_w_mem = ex_mem_out.reg_w_alu;
	wire [4:0]rs2_add;
	assign rs2_add = ex_mem_out.rs2_add;
	wire ecall_mem;
	assign ecall_mem = ex_mem_out.ex_mem_ecall;

	Data_mem dmem1(.clk(clk),.address(ex_mem_out.ALU_result),.opcode(ex_mem_out.opcode),.func3(ex_mem_out.func3),.rs2(forwarded_rs2_sw),.reg_w_data(reg_w_data_dmem));

		

//have to stall and forward if next instruction requires the data else if the next to next inst requires the data then directly forward else one more case is if next instruction rd is next to next instructions rs1 or rs2 then insead of forwarding from mem then forward from ex.

	always@(*)begin
		mem_wb_in.pc = pc_mem;
		mem_wb_in.rd = rd_mem;
		mem_wb_in.ALU_result = ALU_result_mem;
		mem_wb_in.opcode = opcode_mem;
		mem_wb_in.imm_gen = imm_gen_mem;
		mem_wb_in.reg_w_mem = reg_w_mem;
		mem_wb_in.mem_wb_ecall = ecall_mem;
	end
	
	wb wb1(.opcode(mem_wb_out.opcode),.ALU_result(mem_wb_out.ALU_result),.reg_w_data_dmem(reg_w_data_dmem),.reg_w_id(mem_wb_out.reg_w_mem),.pc(mem_wb_out.pc),.imm_gen(mem_wb_out.imm_gen),.reg_w(reg_w),.reg_w_data(reg_w_data));

	wire [4:0]rd_wb;
	assign rd_wb = mem_wb_out.rd;
	wire [1:0]reg_w_wb;
	assign reg_w_wb = mem_wb_out.reg_w_mem;
	wire ecall_wb = mem_wb_out.mem_wb_ecall;
	// Forwarding Logic
	reg [31:0]forwarded_rs2_sw;
	reg [31:0]forwarded_reg_1;
	reg [31:0]forwarded_reg_2;

	always@(*)begin
		jalr_reg_1 = id_ex_out.reg_1_data;
		stall = 1'b0;
		if(reg_w_mem == 2'b11)begin
			if(rd_mem == r_s1_ex)begin
				jalr_reg_1 = ex_mem_out.ALU_result;
			end
		end
		if(reg_w_wb[1] == 1)begin
			if(rd_wb == r_s1_ex && !(r_s1_ex == rd_mem && reg_w_mem != 2'b00))begin
				jalr_reg_1 = reg_w_data;
			end
		end	
		if(reg_w_ex == 2'b10)begin//stall
			if((rd_ex == id_ex_in.rs1 || (opcode != 7'b0100011 && rd_ex == id_ex_in.rs2))&& opcode == 7'b1100111)begin
				stall = 1'b1;
			end
		end
	end

	wire njjrla_id =  !(opcode == 7'b0010111 || opcode == 7'b0110111 || opcode == 7'b1101111 || opcode == 7'b1100111);

	wire njjrla = !(opcode_ex == 7'b0010111 || opcode_ex == 7'b0110111 || opcode_ex == 7'b1101111 || opcode_ex == 7'b1100111);
	always@(*)begin
		stall = 0;
		forwarded_rs2_sw = ex_mem_out.rs2;
		forwarded_reg_1 = id_ex_out.reg_1_data;
		forwarded_reg_2 = id_ex_out.reg_2_data;
		if(opcode_ex == 7'b0110111)begin
			forwarded_reg_1 = 32'd0;
		end 
		if(opcode_ex == 7'b0010111)begin
			forwarded_reg_1 = pc_ex;
		end
		if(opcode_ex == 7'b1101111 || opcode_ex == 7'b1100111)begin
			forwarded_reg_1 = pc_ex;
			forwarded_reg_2 = 32'd4;
		end
		if(reg_w_mem == 2'b11)begin
			if(rd_mem == r_s1_ex && njjrla)begin
				forwarded_reg_1 = ex_mem_out.ALU_result;
			end
			if(rd_mem == r_s2_ex && njjrla)begin
				forwarded_reg_2 = ex_mem_out.ALU_result;
			end
		end
		if(reg_w_wb == 2'b11)begin
			if(rd_wb == r_s1_ex && !(r_s1_ex == rd_mem && reg_w_mem != 2'b00) && njjrla)begin
				forwarded_reg_1 = mem_wb_out.ALU_result;
			end
			if(rd_wb == r_s2_ex && !(r_s2_ex == rd_mem && reg_w_mem != 2'b00) && njjrla)begin
				forwarded_reg_2 = mem_wb_out.ALU_result;
			end
			if(opcode_mem == 7'b0100011 && (rd_wb == rs2_add))begin
				forwarded_rs2_sw = mem_wb_out.ALU_result;
			end

		end	
		if(reg_w_ex == 2'b10)begin//stall
			if((rd_ex == id_ex_in.rs1 || (opcode != 7'b0100011 && rd_ex == id_ex_in.rs2))&&njjrla_id)begin
				stall = 1;
			end
		end
		if(reg_w_wb == 2'b10)begin
			if(rd_wb == r_s1_ex &&  !(r_s1_ex == rd_mem && reg_w_mem != 2'b00) && njjrla)begin
				forwarded_reg_1 = reg_w_data_dmem;
			end
			if(rd_wb == r_s2_ex && !(r_s2_ex == rd_mem && reg_w_mem != 2'b00) && njjrla)begin
				forwarded_reg_2 = reg_w_data_dmem;
			end
			if(opcode_mem == 7'b0100011 && (rd_wb == rs2_add))begin
				forwarded_rs2_sw = reg_w_data_dmem;
			end
		end
	end
// Assign your pipeline registers directly to the top-level output ports
    assign current_pc_debug   = if_id_out.pc;
    assign current_inst_debug = if_id_out.inst;
	assign sim_halt = ecall_wb;

endmodule
