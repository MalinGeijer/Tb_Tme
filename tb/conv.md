  ConvolutionDecodeBlock_B : block
  begin
    ---------------------------------------------------------------------------
    -- Purpose : Receive and decode the received encoded convolution stream.
    --           Process puts all decoded data in a buffer
    ---------------------------------------------------------------------------
    ConvolutionalDecode_P : process
      type State_T is record
        Valid     : boolean;
        NibbleVec : NibbleVec_T(0 to 3);
        State     : std_ulogic_vector(1 to 6);
      end record;
      type StateVec_T is array (natural range 0 to 63) of State_T;
      variable State : StateVec_T;

      variable DecData   : std_ulogic_vector(3 downto 0);
      variable Err       : boolean;
      variable ValidCnt  : natural;
      variable Index     : natural range 0 to 63;
      variable TmDataTmp : Byte_T;
      variable C1Vec     : Nibble_T;
      variable C2Vec     : Nibble_T;

      -----------------------------------------------------------------------
      -- Purpose : Reset
      -----------------------------------------------------------------------
      procedure ResetP is
      begin
        for Init in StateVec_T'range loop
          State(Init) := (Valid     => true,
                          NibbleVec => (others => (others => '0')),
                          State     => To_StdULogicVector(Init, 6));
        end loop;
        DecData        := (others => '0');
        ValidCnt       := 0;
        Index          := 0;
        TmDataTmp      := Byte_C;
        C1Vec          := (others => '0');
        C2Vec          := (others => '0');
        SyncState      <= WaitForSync_E;
        SyncCnt        <= 0;
        TmSynched      <= false;
        UpdatePrBuffer <= false;
        PrBuffer.Clear;
        FlushRaw;
      end procedure ResetP;

      -----------------------------------------------------------------------
      -- Purpose : Add data to PrBuffer
      -----------------------------------------------------------------------
      procedure PushPrBuffer(D : Nibble_T) is
      begin
        for I in D'range loop
          PrBuffer.Push(D(I));
        end loop;
        UpdatePrBuffer <= true;
      end procedure PushPrBuffer;

      -----------------------------------------------------------------------
      -- Purpose : Decode Convolutional Code with 1 symbol input
      -----------------------------------------------------------------------
      procedure ConvolutionalDecode(
        variable State  : inout std_ulogic_vector(1 to 6);
        constant C1     :       std_ulogic;
        constant C2     :       std_ulogic;
        variable DecBit : out   std_ulogic;
        variable Err    : out   boolean) is
        variable C1Tmp      : std_ulogic;
        variable C2Tmp      : std_ulogic;
        variable DecodedVal : std_ulogic;
      begin
        DecodedVal := '0';
        Err        := true;
        GuessLoop : for I in 0 to 1 loop
          -- Perform an encoding with the input bit '0' or '1' and
          -- compare the encoded value with the received encoded.
          -- If a match is found it means that the input was 'I'.
          -- Used the same convolutional encoding as in ECSS-E-ST-50-01C
          C1Tmp := To_StdULogic(I) xor State(1) xor State(2) xor
                   State(3) xor State(6);
          C2Tmp := To_StdULogic(I) xor State(2) xor State(3) xor
                   State(5) xor State(6) xor '1';

          -- Compare guessed value with received value
          if C1Tmp = C1 and C2Tmp = C2 then
            -- A match is found, meaning that State is the same as in rtl
            -- and we can use this fact to propagate the decoded bit
            -- without error.
            DecodedVal := To_StdULogic(I);
            Err        := false;
            exit GuessLoop;
          end if;
        end loop GuessLoop;
        -- Update the State with the new value
        State  := DecodedVal & State(1 to 5);
        DecBit := DecodedVal;
      end procedure ConvolutionalDecode;

      -----------------------------------------------------------------------
      -- Purpose : Decode Convolutional Code with 8 symbols input
      -----------------------------------------------------------------------
      procedure ConvolutionalDecode(
        variable State   : inout std_ulogic_vector(1 to 6);
        constant C1Vec   : in    std_ulogic_vector(3 downto 0);
        constant C2Vec   : in    std_ulogic_vector(3 downto 0);
        variable DecData : out   std_ulogic_vector(3 downto 0);
        variable Err     : out   boolean) is
        variable D     : std_ulogic_vector(3 downto 0);
        variable Err_L : boolean;
      begin
        Err := false;
        for J in 3 downto 0 loop
          -- Decode all four pairs of symbols
          ConvolutionalDecode(State, C1Vec(J), C2Vec(J), D(J), Err_L);
          if Err_L then
            -- Store if an error has been detected
            Err := true;
          end if;
        end loop;
        DecData := D;
      end procedure ConvolutionalDecode;

    begin
      ResetP;
      loop
        wait on UpdateConvBuffer'transaction, ReSynchTm, TmIfInactive;
        if ReSynchTm or TmIfInactive then
          ResetP;
        elsif ConvBuffer.Size > 1 then
          -- Wait for data to be received
          ValidCnt              := 0;
          -- Fetch data from convolutional receive buffer
          TmDataTmp(7 downto 4) := ConvBuffer.Pop;
          TmDataTmp(3 downto 0) := ConvBuffer.Pop;
          C1Vec                 := TmDataTmp(7) & TmDataTmp(5) &
                                   TmDataTmp(3) & TmDataTmp(1);
          C2Vec                 := TmDataTmp(6) & TmDataTmp(4) &
                                   TmDataTmp(2) & TmDataTmp(0);
          if TmInterface_K = TmeUnEnc_E then
            PushPrBuffer(TmDataTmp(7 downto 4));
            PushPrBuffer(TmDataTmp(3 downto 0));
            SyncState <= InSync_E;
          elsif TmInterface_K = TmeByte_E then
            PushPrBuffer(TmDataTmp(7 downto 4));
            PushPrBuffer(TmDataTmp(3 downto 0));
            SyncState <= InSync_E;
          elsif not TmConfig_K.CE then
            if TmInterface_K = TmeEnc_E then
              SyncState <= InSync_E;
              PushPrBuffer(TmDataTmp(7 downto 4));
              wait for MinResolutionTime;
              PushPrBuffer(TmDataTmp(3 downto 0));
              LogRawByte(TmDataTmp);
            else
              LogE("Decoding of data for selected configuration is not " &
                   "supported yet");
            end if;
          else
            -- Convolutional decode received data
            case SyncState is
              -----------------------------------------------------------------
              -- WaitForSync : The decoder is not in synch with the RTL.
              --               Stay here and try to synch.
              -----------------------------------------------------------------
              when WaitForSync_E =>
                -- Loop for all possible positions on the convolution
                -- encode mechanism in the RTL code.
                for I in 0 to 63 loop
                  if State(I).Valid then
                    -- Decode the received symbols
                    ConvolutionalDecode(State   => State(I).State,
                                        C1Vec   => C1Vec,
                                        C2Vec   => C2Vec,
                                        DecData => DecData,
                                        Err     => Err);
                    if Err then
                      -- An error detected, 'I' was not the current position.
                      State(I).Valid     := false;
                      State(I).NibbleVec := (others => (others => '0'));
                    else
                      -- Continue to search for more valid candidates
                      ValidCnt := ValidCnt + 1;
                      Index    := I;
                      State(I).NibbleVec :=
                        State(I).NibbleVec(1 to State(I).NibbleVec'right) &
                        DecData;
                    end if;
                  end if;
                end loop;

                -- When only one candidate remains it means that we have found
                -- the same State value as the convolution encoder.
                -- Wait until the decoding has been performed for 4 groups of
                -- received symbols without error before considering the
                -- decoding correct.
                if ValidCnt = 1 then
                  if SyncCnt >= 3 then
                    Log("Convolutional Decoder in sync");
                    SyncState <= InSync_E;
                    for I in State(Index).NibbleVec'range loop
                      -- Add decoded data to buffer
                      PushPrBuffer(State(Index).NibbleVec(I));
                    end loop;
                  else
                    SyncCnt <= SyncCnt + 1;
                  end if;
                else
                  SyncCnt <= 0;
                end if;

              -----------------------------------------------------------------
              -- InSync :  The convolution decoder has synched to the RTL and
              --           propagates all data.
              -----------------------------------------------------------------
              when InSync_E =>
                -- Decode all incoming data.
                ConvolutionalDecode(State   => State(Index).State,
                                    C1Vec   => C1Vec,
                                    C2Vec   => C2Vec,
                                    DecData => DecData,
                                    Err     => Err);
                if not Err then
                  -- Override default value on ValidCnt if no error.
                  ValidCnt := 1;
                end if;
                -- Add decoded data to buffer
                PushPrBuffer(DecData);
            end case;

            if ValidCnt = 0 then
              -- An error has been detected, restart and try to synch again.
              ResetP;
            end if;
          end if;
          TmSynched <= SyncState = InSync_E;
        end if;
      end loop;
    end process ConvolutionalDecode_P;
  end block ConvolutionDecodeBlock_B;