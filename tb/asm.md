AsmDetectionBlock_B : block
begin
  Asm_P : process
    variable TmDataShift  : std_ulogic_vector(6692 downto 0);  -- TODO: add constant
    variable AsmPattern   : std_ulogic_vector(191 downto 0);
    variable AsmLength    : natural;

    -----------------------------------------------------------------------
    -- Purpose : Reset ASM detection
    -----------------------------------------------------------------------
    procedure ResetP is
    begin
      TmDataShift := (others => '0');
      AsmPattern  := (others => '0');
      Synced      <= false;
    end procedure ResetP;

  begin
    ResetP;
    loop
      wait on UpdatePrBuffer'transaction;
      
      -- When something new in PR buffer
      if UpdatePrBuffer'active or TmCycle'event then        

        if TmConfig_K.Turbo = Turbo2_E then
          AsmLength := AsmLength8_C;
          AsmPattern(8 * AsmLength - 1 downto 0)  := Asm8_C;
        elsif TmConfig_K.Turbo = Turbo4_E or TmConfig_K.Ldpc /= None_E then
          AsmLength := AsmLength16_C;
          AsmPattern(8 * AsmLength - 1 downto 0)  := Asm16_C; 
        elsif TmConfig_K.Turbo = Turbo6_E then
          AsmLength := AsmLength24_C;
          AsmPattern(8 * AsmLength - 1 downto 0)  := Asm24_C;
        else
          AsmLength := AsmLength4_C;
          AsmPattern(8 * AsmLength - 1 downto 0)  := Asm4_C;    
        end if;

        if not PrBuffer.Empty  then   
          -- Shift in 1 bit from PR buffer       
          TmDataShift := TmDataShift(6691 downto 0) & PrBuffer.Pop;   -- TODO: add constant
          if TmDataShift(8 * AsmLength - 1 downto 0) = AsmPattern(8 * AsmLength - 1 downto 0) then
            Log("Synced: Found ASM = " & ImageHex(TmDataShift(8 * AsmLength - 1 downto 0)));
            Synced <= true;
            wait on TmCycle;
            Log("ASM detection restart");
            ResetP;
          end if;
        end if;
      else 
        Log("PR buffer is empty");
      end if;

    end loop;
  end process Asm_P;
end block AsmDetectionBlock_B;