module sinfo #(
	parameter 
		GROUPS,	// количество групп	
		WORDS,	// количество слов	
		WIDTH,// разрядность слов
		ALL_BITS = WIDTH * WORDS * GROUPS
)(
	input clk,
	input [ALL_BITS-1:0] d,
	output reg q = '0
);

localparam BIT_COUNT = $clog2( WIDTH + 1 );
localparam WORD_COUNT = $clog2( WORDS + 1 );
localparam GROUP_COUNT = $clog2( GROUPS + 1 );

reg [1:0] view_count = '0;							// счетчик интервала отображения бита
reg	[BIT_COUNT-1:0] bit_count = '0;					// счетчик бит
reg	[WORD_COUNT-1:0] word_count = '0;				// счетчик слов
reg	[GROUP_COUNT-1:0] group_count = '0;				// счетчик слов
reg	[ALL_BITS-1:0] shift_d = '0;					// регистр сдвига данных
wire view_stb = view_count == '1;					// строб отображения бита
wire last_bit = bit_count == WIDTH;					// последний бит в слове
wire last_word = word_count == WORDS;				// последнее слово данных
wire last_group = group_count == GROUPS;			// последнее слово данных

always @(posedge clk) begin
	view_count <= view_count + 1;								
	if ( view_stb ) begin
		if ( last_bit ) begin
			bit_count <= 0;
			if ( last_word ) begin
				word_count <= 0;
				if ( last_group ) begin
					group_count <= 0;
					shift_d <= d;
				end
				else
					group_count <= group_count + 1;
			end
			else
				word_count <= word_count + 1;
		end
		else begin
			if ( !last_word )
				shift_d <= shift_d<<1;
			bit_count <= bit_count + 1;
		end
	end
// кодер отображения бита: "1" - 3 интервала, "0" - 1 интервал
	if( last_bit | last_word | last_group)
		q <= 1'b0;
	else begin
		if( shift_d[ALL_BITS-1] )
			q <= (view_count == 0)
				|(view_count == 1)
				|(view_count == 2);
		else
			q <= (view_count == 1);
	end
end

endmodule
