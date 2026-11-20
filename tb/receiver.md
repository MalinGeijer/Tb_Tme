  ReceiveBlock_B : block
  begin
    TmIfInactive     <= TmIfInactiveVec(TmInterface_K);
    UpdateConv_P : process
    begin
      wait on UpdateConvBufferVec'transaction;
      UpdateConvBuffer <= UpdateConvBufferVec(TmInterface_K);
    end process UpdateConv_P;

    --=========================================================================
    -- Tme
    --=========================================================================
    TmeUnEnc_B : block
    begin
      TmeReceive_P : process
        constant TmeClkTimeout_C : natural := 100;
        variable Asm             : Word_T;
        variable LdpcAsm         : DWord_T;
        variable FirstFrame      : boolean;
        variable TmeDataCnt      : natural;
        variable TmeClkTimeout   : natural;
        variable TmeClkQ         : std_ulogic;
        variable TmeData         : Byte_T;
        -----------------------------------------------------------------------
        -- Purpose : Reset Receive block.
        -----------------------------------------------------------------------
        procedure ResetP is
        begin
          Asm                             := Word_C;
          LdpcAsm                         := DWord_C;
          FirstFrame                      := true;
          TmIfInactiveVec(TmeUnEnc_E)     <= true;
          TmeClkTimeout                   := TmeClkTimeout_C;
          TmeClkQ                         := '0';
          TmeDataCnt                      := 1;
          TmeData                         := (others => '0');
          ConvBuffer.Clear;
          UpdateConvBufferVec(TmeUnEnc_E) <= false;
        end procedure ResetP;
      begin
        ResetP;
        wait on ReSynchTm;  -- Wait for first Synch before sampling data
        loop
          if TmInterface_K /= TmeUnEnc_E then
            wait on TmInterface_K;
            if TmInterface_K /= TmeUnEnc_E then
              next;
            end if;
          end if;
          wait on TmCycle, ReSynchTm;
          if ReSynchTm or TmeClkTimeout = 0 then
            ResetP;
          elsif TmCycle'event then
            if TmeClkQ = '0' and TmeUnEncClk = '1' then
              TmIfInactiveVec(TmeUnEnc_E) <= false;
              TmeClkTimeout               := TmeClkTimeout_C;

              TmeData := TmeData(6 downto 0) & TmeUnEncOut;
              Asm     := Asm(30 downto 0) & TmeUnEncOut;
              LdpcAsm := LdpcAsm(62 downto 0) & TmeUnEncOut;

              if not FirstFrame then
                if TmeDataCnt = 8 then
                  -- Propagate sampled data to the convolutional decode block
                  ConvBuffer.Push(TmeData(7 downto 4));
                  ConvBuffer.Push(TmeData(3 downto 0));
                  UpdateConvBufferVec(TmeUnEnc_E) <= true;
                  TmeDataCnt                      := 1;
                else
                  TmeDataCnt := TmeDataCnt + 1;
                end if;
              end if;

              -- Make sure ASM is nibble aligned when passing to other
              -- processes
              if FirstFrame then
                -- TODO
                -- if Asm = TmConfig_K.Asm then
                --   ConvBuffer.Push(Asm(31 downto 28));
                --   ConvBuffer.Push(Asm(27 downto 24));
                --   ConvBuffer.Push(Asm(23 downto 20));
                --   ConvBuffer.Push(Asm(19 downto 16));
                --   ConvBuffer.Push(Asm(15 downto 12));
                --   ConvBuffer.Push(Asm(11 downto 8));
                --   ConvBuffer.Push(Asm(7 downto 4));
                --   ConvBuffer.Push(Asm(3 downto 0));
                --   UpdateConvBufferVec(TmeUnEnc_E) <= true;
                --   TmeDataCnt                      := 1;
                --   FirstFrame                      := false;
                -- elsif LdpcAsm = TmConfig_K.LdpcAsm then
                --   ConvBuffer.Push(LdpcAsm(63 downto 60));
                --   ConvBuffer.Push(LdpcAsm(59 downto 56));
                --   ConvBuffer.Push(LdpcAsm(55 downto 52));
                --   ConvBuffer.Push(LdpcAsm(51 downto 48));
                --   ConvBuffer.Push(LdpcAsm(47 downto 44));
                --   ConvBuffer.Push(LdpcAsm(43 downto 40));
                --   ConvBuffer.Push(LdpcAsm(39 downto 36));
                --   ConvBuffer.Push(LdpcAsm(35 downto 32));
                --   ConvBuffer.Push(LdpcAsm(31 downto 28));
                --   ConvBuffer.Push(LdpcAsm(27 downto 24));
                --   ConvBuffer.Push(LdpcAsm(23 downto 20));
                --   ConvBuffer.Push(LdpcAsm(19 downto 16));
                --   ConvBuffer.Push(LdpcAsm(15 downto 12));
                --   ConvBuffer.Push(LdpcAsm(11 downto 8));
                --   ConvBuffer.Push(LdpcAsm(7 downto 4));
                --   ConvBuffer.Push(LdpcAsm(3 downto 0));
                --   UpdateConvBufferVec(TmeUnEnc_E) <= true;
                --   TmeDataCnt                      := 1;
                --   FirstFrame                      := false;
                -- end if;
              end if;
              -- if Asm = TmConfig_K.Asm and FirstFrame then
              --   ConvBuffer.Push(Asm(31 downto 28));
              --   ConvBuffer.Push(Asm(27 downto 24));
              --   ConvBuffer.Push(Asm(23 downto 20));
              --   ConvBuffer.Push(Asm(19 downto 16));
              --   ConvBuffer.Push(Asm(15 downto 12));
              --   ConvBuffer.Push(Asm(11 downto 8));
              --   ConvBuffer.Push(Asm(7 downto 4));
              --   ConvBuffer.Push(Asm(3 downto 0));
              --   UpdateConvBufferVec(TmeUnEnc_E) <= true;
              --   TmeDataCnt                      := 1;
              --   FirstFrame                      := false;
              -- end if;

            end if;

            if TmeClkTimeout > 0 then
              TmeClkTimeout := TmeClkTimeout - 1;
            end if;

            TmeClkQ := TmeUnEncClk;
          end if;
        end loop;
      end process TmeReceive_P;
    end block TmeUnEnc_B;

    TmeEnc_B : block
    begin
      TmeReceive_P : process
        constant TmeClkTimeout_C : natural := 10000;
        variable TmeDataCnt      : natural;
        variable TmeClkTimeout   : natural;
        variable TmeClkQ         : std_ulogic;
        variable TmeData         : Byte_T;
        variable FirstEdge       : boolean;
        -----------------------------------------------------------------------
        -- Purpose : Reset Receive block.
        -----------------------------------------------------------------------
        procedure ResetP is
        begin
          FirstEdge                     := true;
          TmIfInactiveVec(TmeEnc_E)     <= true;
          TmeClkTimeout                 := TmeClkTimeout_C;
          TmeClkQ                       := '0';
          TmeDataCnt                    := 1;
          TmeData                       := (others => '0');
          ConvBuffer.Clear;
          UpdateConvBufferVec(TmeEnc_E) <= false;
        end procedure ResetP;
      begin
        ResetP;
        wait on ReSynchTm;  -- Wait for first Synch before sampling data
        loop
          if TmInterface_K /= TmeEnc_E then
            wait on TmInterface_K;
            if TmInterface_K /= TmeEnc_E then
              next;
            end if;
          end if;
          wait on TmCycle, ReSynchTm;
          if ReSynchTm or TmeClkTimeout = 0 then
            ResetP;
          elsif TmCycle'event then
            if TmeClkQ = '1' and TmeEncClk = '0' then
              TmIfInactiveVec(TmeEnc_E) <= false;
              TmeClkTimeout             := TmeClkTimeout_C;

              TmeData := TmeData(6 downto 0) & TmeEncOut;
              if FirstEdge then
                FirstEdge := false;
              else
                if TmeDataCnt = 8 then
                  -- Propagate sampled data to the convolutional decode block
                  ConvBuffer.Push(TmeData(7 downto 4));
                  ConvBuffer.Push(TmeData(3 downto 0));
                  UpdateConvBufferVec(TmeEnc_E) <= true;
                  TmeDataCnt                    := 1;
                else
                  TmeDataCnt := TmeDataCnt + 1;
                end if;
              end if;
            end if;

            if TmeClkTimeout > 0 then
              TmeClkTimeout := TmeClkTimeout - 1;
            end if;

            TmeClkQ := TmeEncClk;
          end if;
        end loop;
      end process TmeReceive_P;
    end block TmeEnc_B;

    TmeIQ_B : block
    begin
      TmeReceive_P : process
        constant TmeClkTimeout_C : natural := 100;
        variable TmeDataCnt      : natural;
        variable TmeClkTimeout   : natural;
        variable TmeClkQ         : std_ulogic;
        variable TmeData         : Byte_T;
        -----------------------------------------------------------------------
        -- Purpose : Reset Receive block.
        -----------------------------------------------------------------------
        procedure ResetP is
        begin
          TmIfInactiveVec(TmeIQ_E)     <= true;
          TmeClkTimeout                := TmeClkTimeout_C;
          TmeClkQ                      := '1';
          TmeDataCnt                   := 1;
          TmeData                      := (others => '0');
          ConvBuffer.Clear;
          UpdateConvBufferVec(TmeIQ_E) <= false;
        end procedure ResetP;
      begin
        ResetP;
        wait on ReSynchTm;  -- Wait for first Synch before sampling data
        loop
          if TmInterface_K /= TmeIQ_E then
            wait on TmInterface_K;
            if TmInterface_K /= TmeIQ_E then
              next;
            end if;
          end if;
          wait on TmCycle, ReSynchTm;
          if ReSynchTm or TmeClkTimeout = 0 then
            ResetP;
          elsif TmCycle'event then
            if TmeClkQ = '0' and TmeEncIQClk = '1' then
              TmIfInactiveVec(TmeIQ_E) <= false;
              TmeClkTimeout            := TmeClkTimeout_C;

              TmeData := TmeData(5 downto 0) & TmeEncIOut & TmeEncQOut;

              if TmeDataCnt = 4 then
                -- Propagate sampled data to the convolutional decode block
                ConvBuffer.Push(TmeData(7 downto 4));
                ConvBuffer.Push(TmeData(3 downto 0));
                UpdateConvBufferVec(TmeIQ_E) <= true;
                TmeDataCnt := 1;
              else
                TmeDataCnt := TmeDataCnt + 1;
              end if;
            end if;

            if TmeClkTimeout > 0 then
              TmeClkTimeout := TmeClkTimeout - 1;
            end if;

            TmeClkQ := TmeEncIQClk;
          end if;
        end loop;
      end process TmeReceive_P;
    end block TmeIQ_B;

    TmeSpiff_B : block
    begin
      TmeReceive_P : process
        variable D : Byte_T;
        -----------------------------------------------------------------------
        -- Purpose : Reset Receive block.
        -----------------------------------------------------------------------
        procedure ResetP is
        begin
          TmIfInactiveVec(TmeByte_E)     <= true;
          ConvBuffer.Clear;
          TmeSpiffData.Clear;
          UpdateConvBufferVec(TmeByte_E) <= false;
        end procedure ResetP;
      begin
        ResetP;
        wait on ReSynchTm;  -- Wait for first Synch before sampling data
        loop
          if TmInterface_K /= TmeByte_E then
            wait on TmInterface_K;
            if TmInterface_K /= TmeByte_E then
              next;
            end if;
          end if;
          wait on TmCycle, ReSynchTm;
          if ReSynchTm then
            ResetP;
          elsif TmCycle'event then
            TmIfInactiveVec(TmeByte_E) <= false;
            -- Propagate sampled data to the convolutional decode block
            while TmeSpiffData.Size > 0 loop
              D := TmeSpiffData.Pop;
              ConvBuffer.Push(D(7 downto 4));
              ConvBuffer.Push(D(3 downto 0));
            end loop;
            UpdateConvBufferVec(TmeByte_E) <= true;
          end if;
        end loop;
      end process TmeReceive_P;
    end block TmeSpiff_B;

  end block ReceiveBlock_B;