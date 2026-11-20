  PrBlock_B : block is
    constant Verbose_C : boolean := false;
  begin
    Pr_P : process
      variable AsmData       : Word_T;
      variable LdpcAsm       : DWord_T;
      -- variable TurboAsm      : std_ulogic_vector(63 downto 0);
      variable PseudoRand    : std_ulogic_vector(8 downto 1);
      variable PseudoRandPol : std_ulogic_vector(16 downto 0);
      variable Cnt           : natural;
      variable Data          : Byte_T;
      variable FirstFrame    : boolean;

      -----------------------------------------------------------------------
      -- Purpose : Reset PseudoRandom
      -----------------------------------------------------------------------
      procedure ResetP is
      begin
        AsmData             := Word_C;
        LdpcAsm             := DWord_C;
        -- TurboAsm            := (others => '0');
        Cnt                 := 0;
        Data                := Byte_C;
        FirstFrame          := true;
        UpdateReceiveBuffer <= false;
        PrState             <= FirstAsm_E;
        PseudoRand          := (others => '0');
        PseudoRandPol       := (others => '0');
        ReceiveBuffer.Clear;
        ByteStream.Clear;
        UpdateByteStreamCnt1 <= true;
      end procedure ResetP;

      -----------------------------------------------------------------------
      -- Purpose : Add data to ReceiveBuffer
      -----------------------------------------------------------------------
      procedure PushReceiveBuffer(D : Byte_T) is
      begin
        ReceiveBuffer.Push(D);
        UpdateReceiveBuffer <= true;
      end procedure PushReceiveBuffer;

    begin
      ResetP;
      loop
        wait on SyncState, UpdatePrBuffer'transaction, TmCycle;
        if SyncState = WaitForSync_E then
          ResetP;
        elsif UpdatePrBuffer'active or TmCycle'event then
          case PrState is
            -----------------------------------------------------------------
            -- FirstAsm : Synchronize buffer to the first ASM. Go to Data
            --            when first ASM is found.
            -----------------------------------------------------------------
            when FirstAsm_E =>
              -- if TmInterface_K = TmeByte_E then
              --   -- No ASM
              --   PrState <= Data_E;
              -- else
              --   Cnt := 0;
              --   if PrBuffer.Size >= 4 then
              --     -- TODO
              --     AsmLoop : for I in 1 to 4 loop
                    -- if TmConfig_K.Turbo then
                    --   TurboAsm := TurboAsm(62 downto 0) & PrBuffer.Pop;
                    --elsif TmConfig_K.UseLdpcAsm then
                      --LdpcAsm := LdpcAsm(62 downto 0) & PrBuffer.Pop;
                    -- else
                      -- AsmData  := AsmData(30 downto 0) & PrBuffer.Pop;
                    -- end if;
                    -- if (AsmData = TmConfig_K.Asm and not TmConfig_K.Turbo and
                    --     not TmConfig_K.UseLdpcAsm) or
                    --    (TurboAsm = TmConfig_K.TurboAsm and TmConfig_K.Turbo) or
                    --    (LdpcAsm = TmConfig_K.LdpcAsm and TmConfig_K.UseLdpcAsm)
                    -- then
                    -- if (AsmData = TmConfig_K.Asm and not TmConfig_K.UseLdpcAsm) or
                    --    (LdpcAsm = TmConfig_K.LdpcAsm and TmConfig_K.UseLdpcAsm)
                    -- then  
                      -- if not TmConfig_K.PrPol then
                      --   PseudoRand := (others => '1');
                      --   PseudoRand := NextPseudoRand(Start => true,
                      --                                N     => 8,
                      --                                X     => PseudoRand,
                      --                                P     =>
                      --                                Tb_PrX8_X7_X5_X3_1_C);
                      -- else
                      --   PseudoRandPol := "11000111000111000";
                      --   PseudoRandPol := NextPseudoRand(Start => true,
                      --                                   N     => 17,
                      --                                   X     => PseudoRandPol,
                      --                                   P     =>
                      --                                   Tb_PrX17_X14_1_C);
                      -- end if;

                      -- if ByteStreamEnable.Get then
                      --   if TmConfig_K.Turbo then
                      --     LogE("ByteStream for turbo not supported yet");
                      --   else
                      --     ByteStream.Push(AsmData(31 downto 24));
                      --     ByteStream.Push(AsmData(23 downto 16));
                      --     ByteStream.Push(AsmData(15 downto 8));
                      --     ByteStream.Push(AsmData(7 downto 0));
                      --     UpdateByteStreamCnt1 <= true;
                      --   end if;
                      -- end if;
                      -- AsmData    := Word_C;
              --         LdpcAsm    := DWord_C;
              --         -- TurboAsm   := (others => '0');
              --         FirstFrame := false;
              --         PrState    <= Data_E;
              --         if Verbose_C then
              --           Log("Pr_P: ASM Found");
              --         end if;
              --         exit AsmLoop;
              --       -- end if;
              --     end loop;
              --   end if;
              -- end if;
            when Asm_E =>
              -- if PrBuffer.Size >= 4 then
              --   for I in 1 to 4 loop
              --     -- if TmConfig_K.Turbo then
              --     --   TurboAsm := TurboAsm(62 downto 0) & PrBuffer.Pop;
              --     -- els
              --     if TmConfig_K.UseLdpcAsm then
              --       LdpcAsm := LdpcAsm(62 downto 0) & PrBuffer.Pop;
              --     else
              --       AsmData := AsmData(30 downto 0) & PrBuffer.Pop;
              --     end if;
              --   end loop;
              --   Cnt := Cnt + 1;
              -- end if;

              -- if (Cnt = 8 and not TmConfig_K.Turbo and
              --     not TmConfig_K.UseLdpcAsm) or
              --    (Cnt = 16 and (TmConfig_K.Turbo or TmConfig_K.UseLdpcAsm)) then
              --   -- Check Asm after 8/16 nibbles
              --   if (AsmData /= TmConfig_K.Asm and not TmConfig_K.Turbo and
              --       not TmConfig_K.UseLdpcAsm) or
              --      (TurboAsm /= TmConfig_K.TurboAsm and TmConfig_K.Turbo) or
              --      (LdpcAsm /= TmConfig_K.LdpcAsm and TmConfig_K.UseLdpcAsm)
              --   then
                -- if (not TmConfig_K.UseLdpcAsm) or
                --  (Cnt = 16 and TmConfig_K.UseLdpcAsm) then
                -- Check Asm after 8/16 nibbles
                -- if (AsmData /= TmConfig_K.Asm and not TmConfig_K.UseLdpcAsm) or
                --    (LdpcAsm /= TmConfig_K.LdpcAsm and TmConfig_K.UseLdpcAsm)
                -- then  
                --   LogE("Pr_P: No ASM received when expected");
                --   PrState <= FirstAsm_E;
                -- else
                  -- if ByteStreamEnable.Get then
                  --   if TmConfig_K.Turbo then
                  --     LogE("ByteStream for turbo not supported yet");
                  --   else
                  --     ByteStream.Push(AsmData(31 downto 24));
                  --     ByteStream.Push(AsmData(23 downto 16));
                  --     ByteStream.Push(AsmData(15 downto 8));
                  --     ByteStream.Push(AsmData(7 downto 0));
                  --     UpdateByteStreamCnt1 <= true;
                  --   end if;
                  -- end if;

                  PrState    <= Data_E;
                  -- if not TmConfig_K.PrPol then
                  --   PseudoRand := (others => '1');
                  --   PseudoRand := NextPseudoRand(Start => true,
                  --                                N     => 8,
                  --                                X     => PseudoRand,
                  --                                P     => Tb_PrX8_X7_X5_X3_1_C);
                  -- else
                  --   PseudoRandPol := "11000111000111000";
                  --   PseudoRandPol := NextPseudoRand(Start => true,
                  --                                   N     => 17,
                  --                                   X     => PseudoRandPol,
                  --                                   P     => Tb_PrX17_X14_1_C);
                  -- end if;
                -- end if;

              --   Cnt := 0;
              -- end if;
              -- FirstFrame := false;

            when Data_E =>
              -- if (PrBuffer.Size >= 8 and not TmConfig_K.Turbo) or
              --    (PrBuffer.Size >= 16 and TmConfig_K.Turbo) then
              -- if PrBuffer.Size >= 8 or PrBuffer.Size >= 16 then    
              --   -- Fetch next byte
              --   for I in 7 downto 0 loop
              --     Data(I) := PrBuffer.Pop;
              --     -- if TmConfig_K.Turbo then
              --     --   -- Throw away every other bit
              --     --   PrBuffer.Pop;
              --     -- end if;
              --   end loop;

              --   if ByteStreamEnable.Get then
              --     -- if TmConfig_K.Turbo then
              --     --   LogE("ByteStream for turbo not supported yet");
              --     -- else
              --       ByteStream.Push(Data);
              --       UpdateByteStreamCnt1 <= true;
              --     -- end if;

              --   elsif TmConfig_K.PR  and
              --         not FirstFrame and
              --         not (TmInterface_K = TmeUnEnc_E)
              --   then
              --     -- Perform Pseudo Random
              --     if not TmConfig_K.PrPol then
              --       Data       := Data xor PseudoRand;
              --       PseudoRand := NextPseudoRand(Start => false,
              --                                    N     => 8,
              --                                    X     => PseudoRand,
              --                                    P     => Tb_PrX8_X7_X5_X3_1_C);
              --     else
              --       Data          := Data xor PseudoRandPol(16 downto 9);
              --       PseudoRandPol := NextPseudoRand(Start => false,
              --                                       N     => 8,
              --                                       X     => PseudoRandPol,
              --                                       P     => Tb_PrX17_X14_1_C);
              --     end if;
              --   end if;

              --   if not ByteStreamEnable.Get then
              --     -- Propagate data, if ByteStream is not used
              --     PushReceiveBuffer(Data);
              --   end if;

              --   -- Increase number of received data
              --   Cnt := Cnt + 1;
              --   if Cnt >= TmConfig_K.CodeBlockLen then
              --     AsmData  := Word_C;
              --     -- TurboAsm := (others => '0');
              --     LdpcAsm  := (others => '0');
              --     Cnt      := 0;
              --     -- if TmConfig_K.Turbo then
              --       -- PrState <= TurboPadding_E;
              --     -- els
              --     if TmInterface_K /= TmeByte_E then
              --       PrState <= Asm_E;
              --     end if;
              --   end if;
              -- end if;

            when TurboPadding_E =>
              -- Remove Padding bits from stream
              -- if PrBuffer.Size >= 8 then
              --   for I in 1 to 8 loop
              --     PrBuffer.Pop;
              --   end loop;
              --   PrState <= Asm_E;
              -- end if;

          end case;
        end if;
      end loop;
    end process Pr_P;
  end block PrBlock_B;