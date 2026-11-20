  -----------------------------------------------------------------------------
  -- Purpose : To receive and check received frames.
  -----------------------------------------------------------------------------
  TmFrameReceive_P : process
    constant Verbose_C           : boolean                        := false;
    constant VerboseData_C       : boolean                        := false;
    constant VerboseRs_C         : boolean                        := false;
    constant Ivs_C               : std_ulogic_vector(63 downto 0) := (others => '0');
    constant ScidConfigTimeout_C : natural                        := 4;
    variable Data                : Byte_T;
    variable TmData              : ByteVec_T(0 to MaxTmFrameLen_C - 1);
    variable TmActData           : ByteVec_T(0 to MaxTmFrameLen_C - 1);
    variable TmFrame             : TmFrame_T;
    variable VcId                : natural range 0 to 7;
    variable ExpData             : Byte_T;
    variable Message             : ByteVec_T(0 to 1114);
    variable VcPktVec            : VcPktVec_T;
    variable VcInfo_L            : VcInfoRec_T;
    variable IdlePktIndexVec     : NaturalVec_T(0 to 7);
    variable Seed                : integer;
    variable IdleFrame           : boolean;
    variable CheckFrame          : boolean;
    variable CheckPacket         : boolean;
    variable AnyMatch            : boolean;
    variable ScidConfigTimeout   : natural;
    variable IvsTmp              : std_ulogic_vector(63 downto 0);
    variable MessageLength       : integer;
    variable LdpcVersion         : TBTMLdpcVersion_T;
    variable RsVersion           : TBTMRSVersion_T;
    variable DoResetP            : boolean := true;
    -----------------------------------------------------------------------
    -- Purpose : Reset
    -----------------------------------------------------------------------
    procedure ResetP is
    begin
      if DoResetP then -- Fix for simulation performance
        TmData        := (others => Byte_C);
        TmFrame       := TmFrame_C;
        VcId          := 0;
        CheckFrame    := false;
        CheckPacket   := false;
        FrameCnt      <= 0;
        IdleCnt       <= 0;
        PacketCnt     <= 0;
        IdlePacketCnt <= 0;
        case ResetChCntInfo.GetMst is
          when Zero_E | Auto_E => MstFrameCnt_I <= Byte_C;
          when Keep_E          => null;
        end case;
        for I in VcInfo_I'range loop
          case ResetChCntInfo.GetVc(I) is
            when Zero_E | Auto_E => VcInfo_I <= VcInfo_C;
            when Keep_E          => null;
          end case;
        end loop;
        VcInfo_I             <= VcInfo_C;
        VcIdHistory_I        <= VcIdHistory_C;
        VcPktVec             := VcPktVec_C;
        if CheckPackets_G then
          VcPktVec           := VcPktVec2_C;
        end if;
        LastTmFrame          <= TmFrame_C;
        ScidConfigTimeout    := ScidConfigTimeout_C;
        ScidConfigUsed       <= (others => '1');  -- Should /= (others => '0').
        TmFrameBuffer.Clear;
        UpdateTmFrameBuffer1 <= false;
      end if;
      DoResetP := false;
    end procedure ResetP;

    -----------------------------------------------------------------------
    -- Purpose : Check Header fields and Reed Solomon or Ldpc
    -----------------------------------------------------------------------
    procedure CheckTmFrame(Frame       : TmFrame_T;
                           TmData      : ByteVec_T;
                           MstFrameCnt : Byte_T;
                           VcFrameCnt  : Word_T) is
      variable ExpFrame   : TmFrame_T;
      variable IdleFrame  : boolean;
      variable ExpIdleFrameData :
        ByteVec_T(0 to 2 * TmFrame_C.DataField'length - 1);
      variable PseudoRand : std_ulogic_vector(8 downto 0);
      variable VcId       : integer := To_Integer(Frame.PrimHead.VcId);
    begin
      IdleFrame := IsIdleFrame(Frame);
      -- Set equal to avoid errors on non static fields
      ExpFrame  := Frame;

      ---------------------------------------------------------------
      -- Setup expected header field values
      ---------------------------------------------------------------
      -- Primary Header --------------------------------------
      ExpFrame.PrimHead.VerNum           := "00";
      ExpFrame.PrimHead.OperCF           := To_StdULogic(TmConfig_K.UseClcw);
      ExpFrame.PrimHead.MasterChFrameCnt := To_Integer(MstFrameCnt);
      ExpFrame.PrimHead.VcFrameCnt  := To_Integer(VcFrameCnt(7 downto 0));
      ExpFrame.PrimHead.SecHeadFlag := To_StdULogic(TmConfig_K.SecoHead);
      ExpFrame.PrimHead.SyncFlag    := '0';
      ExpFrame.PrimHead.OrderFlag   := '0';
      ExpFrame.PrimHead.SegLengthId := "11";

      -- Secondary Header ------------------------------------
      if TmConfig_K.SecoHead then
        ExpFrame.SecHead.VerNum        := TmConfig_K.SecoVer;
        ExpFrame.SecHead.SecHeadLength := TmConfig_K.SecHeadLen - 1;
        if TmConfig_K.ShVcCnt then
          if TmConfig_K.SecHeadLen > 1 then
            ExpFrame.SecHead.ExtVcFc(23 downto 16) := VcFrameCnt(31 downto 24);
          end if;
          if TmConfig_K.SecHeadLen > 2 then
            ExpFrame.SecHead.ExtVcFc(15 downto 8) := VcFrameCnt(23 downto 16);
          end if;
          if TmConfig_K.SecHeadLen > 3 then
            ExpFrame.SecHead.ExtVcFc(7 downto 0) := VcFrameCnt(15 downto 8);
          end if;
        end if;
        ExpFrame.SecHead.Data := SecHead_C.Data;
      else
        ExpFrame.SecHead := SecHead_C;
      end if;

      -- Security Header -------------------------------------
      ExpFrame.SecuHead := SecuHead_C; -- Always 0

      -- Security Trailer ------------------------------------
      ExpFrame.SecuTrailer := SecuTrailer_C; -- Always 0

      -- Trailer ---------------------------------------------
      ExpFrame.Trailer := Trailer_C;
      if TmConfig_K.UseClcw and not TmConfig_K.NoCheckClcw then
        -- First Frame is a dummy thus Clcw index 2 is used for
        -- first frame when
        ExpFrame.Trailer.Opcf := To_ByteVecT(
          ClcwDataQ(To_Integer(MstFrameCnt) mod ClcwDataQ'length));
      else
        -- In nocheck mode, report observed
        ClcwDataSmpQ <= ClcwDataSmp;
        ClcwDataSmp  <= To_WordVecT(Frame.Trailer.Opcf)(0);
        -- Cheat to pass check
        ExpFrame.Trailer.Opcf := Frame.Trailer.Opcf;
      end if;
      if TmConfig_K.UseFecw then
        MessageLength := TmConfig_K.CodeBlockLen - TmConfig_K.CsLen - 2;
        ExpFrame.Trailer.Fecw := To_ByteVecT(CalcCrc(
          Data => TmData(0 to MessageLength - 1),
          P    => Tb_CrcX16_X12_X5_1_C,
          Crc  => X"FFFF"));
      end if;

      ---------------------------------------------------------------
      -- Verify known fields in:
      --    - Primary Header
      --    - Secondary Header
      --    - Security Header
      --    - Security Trailer
      --    - Trailer
      ---------------------------------------------------------------
      CheckValue(Frame.PrimHead, "Frame.PrimHead",
                 ExpFrame.PrimHead, Verbose_C);
      CheckValue(Frame.SecHead, "Frame.SecHead",
                 ExpFrame.SecHead, Verbose_C);
      CheckValue(Frame.SecuHead, "Frame.SecuHead",
                 ExpFrame.SecuHead, Verbose_C);
      CheckValue(Frame.SecuTrailer, "Frame.SecuTrailer",
                 ExpFrame.SecuTrailer, Verbose_C);
      CheckValue(Frame.Trailer, "Frame.Trailer",
                 ExpFrame.Trailer, Verbose_C);

      ---------------------------------------------------------------
      -- Verify Ldpc/Reed Solomon
      ---------------------------------------------------------------

      MessageLength := TmConfig_K.CodeBlockLen - TmConfig_K.CsLen;
      Message                         := (others => Byte_C);
      Message(0 to MessageLength - 1) := TmData(0 to MessageLength - 1);

      if TmConfig_K.CsLen > 0 then
        if TmConfig_K.Length = 512 then
          case TmConfig_K.CsLen is
            when 128 => LdpcVersion := K4096R45_E;
            when 256 => LdpcVersion := K4096R23_E;
            when 512 => LdpcVersion := K4096R12_E;
            when others =>
              LogE("Unsupported Ldpc configuration");
              LdpcVersion := K4096R12_E;
          end case;

          TBTMLdpc_Encode(Version => LdpcVersion,
                          Message => Message(0 to MessageLength - 1),
                          Check => ExpFrame.CsBytes(0 to TmConfig_K.CsLen - 1));

        elsif TmConfig_K.RS then
          ExpFrame.CsBytes := TmFrame_C.CsBytes;
          -- Perform RS encode on all received data
          case TmConfig_K.CsLen is
            when 32     => RsVersion := E16Interleave1_E;
            when 64     => RsVersion := E16Interleave2_E;
            when 128    => RsVersion := E16Interleave4_E;
            when 160    => RsVersion := E16Interleave5_E;
            when others =>
              LogE("Unsupported RS configuration");
              RsVersion := E16Interleave5_E;
          end case;

          TBTMRS_Encode(Version => RsVersion,
                        Message => Message(0 to MessageLength - 1),
                        Check   => ExpFrame.CsBytes(0 to TmConfig_K.CsLen - 1));
        end if;
      end if;
      -- Verify received Ldpc/Reed Solomon check symbols
      for I in Frame.CsBytes'range loop
        CheckValue(Frame.CsBytes(I), "Frame.CsBytes(" & To_String(I) & ")",
                   ExpFrame.CsBytes(I), VerboseRs_C);
      end loop;

      ---------------------------------------------------------------
      -- Verify Idle Frame data
      ---------------------------------------------------------------
      if IdleFrame then
        -- Idle Frame data is not reset for each Idle Frame,
        -- therefore check data against a 'window'.

        -- Setup expected data
        PseudoRand := (others => '1');
        for I in ExpIdleFrameData'range loop
          -- Idle frame data shall use polynomial X9_X4_1.
          PseudoRand := NextPseudoRand(Start => I = ExpIdleFrameData'left,
                                       N     => 8,
                                       X     => PseudoRand,
                                       P     => Tb_PrX9_X4_1_C);
          ExpIdleFrameData(I) := PseudoRand(8 downto 1);
        end loop;

        CheckValue(Frame.DataField(0 to TmConfig_K.VcDataFieldLen(VcId) - 1),
                   "Frame.DataField",
                   ExpIdleFrameData(0 to TmConfig_K.VcDataFieldLen(VcId) - 1),
                   Verbose => false);

        -- Check data against expected
        for I in 0 to MaxDataFieldLen_C - 1 loop
          exit when
            Frame.DataField(0 to TmConfig_K.VcDataFieldLen(VcId) - 1) =
            ExpIdleFrameData(I to I + TmConfig_K.VcDataFieldLen(VcId) - 1);

          if I = MaxDataFieldLen_C - 1 then
            LogE("Idle Frame data is incorrect");
            Log("IdleData = " & To_String(Frame.DataField));
          end if;
        end loop;
      end if;
    end procedure CheckTmFrame;

  begin
    ResetP;
    loop
      wait on SyncState, UpdateReceiveBuffer'transaction;
      if SyncState = WaitForSync_E then
        ResetP;
      elsif UpdateReceiveBuffer'active then
        DoResetP := true;
        if ReceiveBuffer.Size >= TmConfig_K.CodeBlockLen then
          -- All data received in TM frame.
          -- Fetch all data bytes
          TmData := (others => Byte_C);
          for I in 0 to TmConfig_K.CodeBlockLen - 1 loop
            TmData(I)           := ReceiveBuffer.Pop;

            -- Keep the actual data found aswell before decrypting. Clcw and
            -- Crc inside Tme2 are generated from these, not from the decrypted
            -- values.
            TmActData(I) := TmData(I);
            if TmConfig_K.Sdls then
              -- Perform 'simple' decryption on encrypted data part
              if I < (TmConfig_K.CodeBlockLen -
                      TmConfig_K.CsLen -
                      4 * To_Integer(TmConfig_K.UseClcw) -
                      2 * To_Integer(TmConfig_K.UseFecw))
              then
                TmData(I) := not TmData(I);
              end if;
            end if;
          end loop;

          -- Log("Frame seen: " & To_String(TmData(0 to 5)) &
          --     " " & To_String(TmData(6 to 9)) &
          --     " " & To_String(TmData(10 to 19)));

          -- All non-existant fields, due to TmConfig_K, in TmFrame are set to 0
          TmFrame     := To_TmFrameT(TmData, TmConfig_K);
          VcId        := To_Integer(TmFrame.PrimHead.VcId);
          VcInfo_L    := VcInfo_I(VcId);
          IdleFrame   := IsIdleFrame(TmFrame);
          CheckFrame  := CheckFrames  and not CheckPackets and not IdleFrame;
          CheckPacket := CheckPackets and not CheckFrames  and not IdleFrame;

          -- Handle sync of Master Channel Frame Count
          if ResetChCntInfo.GetMst = Auto_E then
            MstFrameCnt_I <= To_ByteT(TmFrame.PrimHead.MasterChFrameCnt);
            ResetChCntInfo.SetMst(Keep_E);
            -- Wait to be able to use updated signal below
            wait for MinResolutionTime;
          end if;

          -- Handle sync of Virtual Channel Frame Count
          if ResetChCntInfo.GetVc(VcId) = Auto_E then
            -- This might not work when current VcFc > 256
            if TmFrame.PrimHead.SecHeadFlag = '1' and TmConfig_K.ShVcCnt and
               TmFrame.SecHead.SecHeadLength >= 3 then
              VcInfo_L.Vcfc(31 downto 8) := TmFrame.SecHead.ExtVcFc;
            end if;
            VcInfo_L.Vcfc(7 downto 0) := To_ByteT(TmFrame.PrimHead.VcFrameCnt);
            ResetChCntInfo.SetVc(VcId, Keep_E);
          end if;

          if IdleFrame then
            if CheckFrame or CheckPacket then
              -- Check Reed Solomon/Ldpc and possible Header fields.
              CheckTmFrame(Frame       => TmFrame,
                           TmData      => TmActData,
                           MstFrameCnt => MstFrameCnt_I,
                           VcFrameCnt  => VcInfo_L.VcFc);
              if Verbose_C then
                Log("Idle Frame received and checked" &
                    ", MstCnt = " & To_String(To_Integer(MstFrameCnt_I)));
              end if;
            end if;
            IdleCnt <= IdleCnt + 1;
          else
            if CheckFrame or CheckPacket then
              -- Check Reed Solomon/Ldpc and possible Header fields.
              CheckTmFrame(Frame       => TmFrame,
                           TmData      => TmActData,
                           MstFrameCnt => MstFrameCnt_I,
                           VcFrameCnt  => VcInfo_L.VcFc);
              Log("TM Frame received and checked: " &
                  "VcId = " & To_String(To_Integer(TmFrame.PrimHead.VcId)) &
                  ", MstCnt = " & To_String(To_Integer(MstFrameCnt_I)) &
                  ", VcCnt = " & To_String(To_Integer(VcInfo_L.VcFc)));
            else
              Log("TM Frame received: " &
                  "VcId = " & To_String(To_Integer(TmFrame.PrimHead.VcId)) &
                  ", MstCnt = " & To_String(To_Integer(MstFrameCnt_I)) &
                  ", VcCnt = " & To_String(To_Integer(VcInfo_L.VcFc)));
            end if;
            FrameCnt <= FrameCnt + 1;
          end if;
          -- Update received VcId history
          VcIdHistory_I <= VcId & VcIdHistory_I(0 to VcIdHistory_I'right-1);

          

          ----------------------------------------------------------------
          -- Check SCID
          ----------------------------------------------------------------
          if TmFrame.PrimHead.ScId /= ScidConfigUsed or ScidConfigTimeout = 0
          then
            if Tb_TmStat_I.PendingUpdateScid then
              CheckValue(TmFrame.PrimHead.Scid, "TmFrame.PrimHead.Scid",
                         ScidConfigNew, Verbose => Verbose_C);
              ScidConfigUsed <= ScidConfigNew;
            else
              -- Will always give error
              CheckValue(TmFrame.PrimHead.Scid, "TmFrame.PrimHead.Scid",
                         ScidConfigUsed, Verbose => Verbose_C);
            end if;
            ScidConfigTimeout := ScidConfigTimeout_C;
          elsif Tb_TmStat_I.PendingUpdateScid then
            -- Decrease timeout if any pending exist
            ScidConfigTimeout := ScidConfigTimeout - 1;
          end if;

          ----------------------------------------------------------------
          -- Update Last received frame
          ----------------------------------------------------------------
          LastTmFrame <= TmFrame;

          ----------------------------------------------------------------
          -- Update Last received Clcw
          ----------------------------------------------------------------
          ClcwFound(To_Integer(MstFrameCnt_I) mod ClcwDataQ'length) <=
            TmFrame.Trailer.Opcf;

          ----------------------------------------------------------------
          -- Check Packets within the TM Frame when not an Idle Frame.
          -- Idle Frames are not checked here since it has already been
          -- verified in the procedure 'CheckTmFrame' above.
          ----------------------------------------------------------------
          if CheckFrame then
            -- Tb_Tm assumes a VCA packet contains the following header:
            -- Byte0 = Expected VcId.
            -- Byte1 = Seed for packet
            -- Byte2 = Msb length of packet
            -- Byte3 = Lsb length of packet
            -- The length of the packet is all bytes except the above
            -- mentioned header, i.e. if Length = 1 then is only a header +
            -- one trailing byte expected. Length must be > 0.

            -- Visual example of a packet:
            -- | VcId | Seed | Len1 | Len0 | Data0 | Data1 | ... |

            -----------------------------------------------------------------
            -- CheckData
            -----------------------------------------------------------------
            for I in 0 to TmConfig_K.VcDataFieldLen(VcId) - 1 loop
              case VcPktVec(VcId).HeadCnt is
                when 4 =>
                  -- Retrieve first byte in the Header
                  VcPktVec(VcId).Dest    := TmFrame.DataField(I);
                  VcPktVec(VcId).HeadCnt := 3;
                  -- Check that destination was as expected
                  if VcPktVec(VcId).Dest = IdlePktHead_C(0) then
                    -- Idle Pkt received
                    VcInfo_L.VcIdlePktCnt  := VcInfo_L.VcIdlePktCnt + 1;
                    -- Check remaining data below
                    VcPktVec(VcId).HeadCnt := 0;
                    VcPktVec(VcId).Len     := To_HalfWordT(IdlePktLen_C - 1);
                    IdlePktIndexVec(VcId)  := 1;
                  else
                    VcInfo_L.VcPktCnt := VcInfo_L.VcPktCnt + 1;
                    -- Verify Virtual Channel Id
                    CheckValue(VcPktVec(VcId).Dest,
                               "VcPktVec("&To_String(VcId)&").Dest",
                               To_ByteT(VcId), Verbose => false);
                  end if;

                when 3 =>
                  -- Retrieve second byte in the Header
                  VcPktVec(VcId).Seed    := To_Integer(TmFrame.DataField(I));
                  VcPktVec(VcId).HeadCnt := 2;

                when 2 =>
                  -- Retrieve third byte in the Header
                  VcPktVec(VcId).Len(15 downto 8) := TmFrame.DataField(I);
                  VcPktVec(VcId).HeadCnt          := 1;

                when 1 =>
                  -- Retrieve fourth byte in the Header
                  VcPktVec(VcId).Len(7 downto 0) := TmFrame.DataField(I);
                  VcPktVec(VcId).HeadCnt         := 0;
                  -- Sanity check that Len > 0
                  exit when not CheckValue(
                    VcPktVec(VcId).Len > 0,
                    "VcPktVec("&To_String(VcId)&").Len > 0",
                    true, Verbose => false);
                  -- Update expected FHP for the next Frame if a partial
                  -- header was received in a previous frame
                  if VcPktVec(VcId).PartialHeadCnt > 0 then
                    -- Update expected FHP
                    if VcPktVec(VcId).PartialHeadCnt = 4 then
                      -- Previous packet ended on the frame block boundary
                      VcPktVec(VcId).Fhp := (others => '0');
                    elsif VcPktVec(VcId).PartialHeadCnt +
                          VcPktVec(VcId).Len >=
                          TmConfig_K.VcDataFieldLen(VcId) then
                      VcPktVec(VcId).Fhp := (others => '1');
                    else
                      VcPktVec(VcId).Fhp := VcPktVec(VcId).PartialHeadCnt +
                                            VcPktVec(VcId).Len(10 downto 0);
                    end if;
                    VcPktVec(VcId).PartialHeadCnt := 0;
                  end if;

                when others =>
                  -- Check data
                  if VcPktVec(VcId).Dest = IdlePktHead_C(0) then
                    -- Checking Idle Packet
                    if IdlePktIndexVec(VcId) <= IdlePktHead_C'length - 1 then
                      -- Only check the Header
                      ExpData := IdlePktHead_C(IdlePktIndexVec(VcId));
                      CheckValue(TmFrame.DataField(I),
                                 "TmFrame.DataField("&To_String(I) & ")",
                                 ExpData, Verbose => false);
                    end if;
                    IdlePktIndexVec(VcId) := IdlePktIndexVec(VcId) + 1;
                  else
                    -- Checking regular packet
                    Randomize(ExpData, VcPktVec(VcId).Seed);
                    CheckValue(TmFrame.DataField(I),
                               "TmFrame.DataField("&To_String(I) & ")",
                               ExpData, Verbose => false);
                  end if;

                  VcPktVec(VcId).Len := VcPktVec(VcId).Len - 1;
                  -- Check next packet when end of packet is reached
                  if VcPktVec(VcId).Len = 0 then
                    VcPktVec(VcId).HeadCnt := 4;
                  end if;
              end case;
            end loop;

            -- Verify First Header Pointer
            CheckValue(TmFrame.PrimHead.FirstHeadPointer,
                       "TmFrame.PrimHead.FirstHeadPointer",
                       VcPktVec(VcId).Fhp, Verbose => Verbose_C);

            -- Update expected FHP for the next Frame
            if VcPktVec(VcId).HeadCnt > 0 then
              -- Partial Header received
              VcPktVec(VcId).PartialHeadCnt := VcPktVec(VcId).HeadCnt;
            else
              if VcPktVec(VcId).Len >= TmConfig_K.VcDataFieldLen(VcId) then
                VcPktVec(VcId).Fhp := (others => '1');
              else
                VcPktVec(VcId).Fhp := VcPktVec(VcId).Len(10 downto 0);
              end if;
            end if;

          ----------------------------------------------------------------
          -- Check Packets within the TM Frame(s) when not an Idle Frame.
          -- Idle Frames are not checked here since it has already been
          -- verified in the procedure 'CheckTmFrame' above.
          ----------------------------------------------------------------
          elsif CheckPacket then
            -- Tb_Tm assumes a VCA packet contains the following header:
            -- Byte0 = Expected VcId.
            -- Byte1 = Seed for packet
            -- Byte4 = Msb Packet Data Length
            -- Byte5 = Lsb Packet Data Length
            -- The Packet Data Length is all bytes except the above
            -- mentioned header, i.e. if Length = 0 then is only a header +
            -- one trailing byte expected. Length must be >= 0. The two "---"
            -- fields are dont care. Will be set to all '0' for every packet.

            -- Visual example of a packet:
            -- | VcId | Seed | --- | --- | Len1 | Len0 | Data0 | Data1 | ... |

            -----------------------------------------------------------------
            -- CheckData
            -----------------------------------------------------------------
            for I in 0 to TmConfig_K.VcDataFieldLen(VcId) - 1 loop
              case VcPktVec(VcId).HeadCnt is
                when 6 =>
                  -- Retrieve first byte in the Header
                  VcPktVec(VcId).Dest    := TmFrame.DataField(I);
                  -- Check that destination was as expected
                  if VcPktVec(VcId).Dest = IdlePktHead_C(0) then
                    -- Idle Pkt received
                    VcInfo_L.VcIdlePktCnt  := VcInfo_L.VcIdlePktCnt + 1;
                    IdlePacketCnt <= IdlePacketCnt + 1;
                    wait for MinResolutionTime;
                    -- Check remaining data below
                    VcPktVec(VcId).HeadCnt := 0;
                    VcPktVec(VcId).Len     := To_HalfWordT(IdlePktLen_C - 2);
                    IdlePktIndexVec(VcId)  := 1;
                  else
                      PacketCnt <= PacketCnt + 1;
                      wait for MinResolutionTime;
                      VcPktVec(VcId).HeadCnt := 5;
                      VcInfo_L.VcPktCnt := VcInfo_L.VcPktCnt + 1;
                      -- Verify Virtual Channel Id
                      CheckValue(VcPktVec(VcId).Dest,
                                 "VcPktVec("&To_String(VcId)&").Dest",
                                 To_ByteT(VcId), Verbose => false);
                    -- end if;
                  end if;

                when 5 =>
                  -- Retrieve second byte in the Header
                  VcPktVec(VcId).Seed    := To_Integer(TmFrame.DataField(I));
                  VcPktVec(VcId).HeadCnt := 4;

                when 4 =>
                  -- Retrieve third byte in the Header
                  VcPktVec(VcId).HeadCnt := 3;
                when 3 =>
                  -- Retrieve fourth byte in the Header
                  VcPktVec(VcId).HeadCnt := 2;
                when 2 =>
                  -- Retrieve fifth byte in the Header
                  VcPktVec(VcId).Len(15 downto 8) := TmFrame.DataField(I);
                  VcPktVec(VcId).HeadCnt          := 1;

                when 1 =>
                  -- Retrieve fifth byte in the Header
                  VcPktVec(VcId).Len(7 downto 0) := TmFrame.DataField(I);
                  VcPktVec(VcId).HeadCnt         := 0;
                  -- Update expected FHP for the next Frame if a partial
                  -- header was received in a previous frame
                  if VcPktVec(VcId).PartialHeadCnt > 0 then
                    -- Update expected FHP
                    if VcPktVec(VcId).PartialHeadCnt = 6 then
                      -- Previous packet ended on the frame block boundary
                      VcPktVec(VcId).Fhp := (others => '0');
                    elsif VcPktVec(VcId).PartialHeadCnt +
                          VcPktVec(VcId).Len + 1 >=
                          TmConfig_K.VcDataFieldLen(VcId) then
                      VcPktVec(VcId).Fhp := (others => '1');
                    else
                      VcPktVec(VcId).Fhp := VcPktVec(VcId).PartialHeadCnt +
                                            VcPktVec(VcId).Len(10 downto 0) + 1;
                    end if;
                    VcPktVec(VcId).PartialHeadCnt := 0;
                  end if;

                when others =>
                  -- Check data
                  if VcPktVec(VcId).Dest = IdlePktHead_C(0) then
                    -- Checking Idle Packet
                    if IdlePktIndexVec(VcId) <= IdlePktHead_C'length - 1 then
                      -- Only check the Header
                      ExpData := IdlePktHead_C(IdlePktIndexVec(VcId));
                      CheckValue(TmFrame.DataField(I),
                                 "TmFrame.DataFieldIdle("&To_String(I) & ")",
                                 ExpData, Verbose => false);
                    end if;
                    IdlePktIndexVec(VcId) := IdlePktIndexVec(VcId) + 1;
                  else
                    -- Checking regular packet
                    Randomize(ExpData, VcPktVec(VcId).Seed);
                    CheckValue(TmFrame.DataField(I),
                               "TmFrame.DataField("&To_String(I) & ")",
                               ExpData, Verbose => false);
                  end if;

                  -- Check next packet when end of packet is reached
                  if VcPktVec(VcId).Len = 0 then
                    VcPktVec(VcId).HeadCnt := 6;
                  else
                    VcPktVec(VcId).Len := VcPktVec(VcId).Len - 1;
                  end if;
              end case;
            end loop;

            -- Verify First Header Pointer
            CheckValue(TmFrame.PrimHead.FirstHeadPointer,
                       "TmFrame.PrimHead.FirstHeadPointer",
                       VcPktVec(VcId).Fhp, Verbose => Verbose_C);

            -- Update expected FHP for the next Frame
            if VcPktVec(VcId).HeadCnt > 0 then
              -- Partial Header received
              VcPktVec(VcId).PartialHeadCnt := VcPktVec(VcId).HeadCnt;
            else
              if VcPktVec(VcId).Len + 1 >= TmConfig_K.VcDataFieldLen(VcId) then
                VcPktVec(VcId).Fhp := (others => '1');
              else
                VcPktVec(VcId).Fhp := VcPktVec(VcId).Len(10 downto 0) + 1;
              end if;
            end if;
          end if;

          -- Update expected Frame counters for the next TM Frame
          -- Master Channel Frame Count
          MstFrameCnt_I <= MstFrameCnt_I + 1;

          -- Virtual Channel Frame Count
          VcInfo_L.VcFc := VcInfo_L.VcFc + 1;

          if not IdleFrame then
            -- Log frame
            LogFrame(TmFrame, TmConfig_K);
          end if;

          if FrameRecording then
            -- Save frame
            TmFrameBuffer.Push(TmFrame);
            UpdateTmFrameBuffer1 <= true;
          end if;

          -- IdlePacketCnt  <= VcInfo_L.VcIdlePktCnt;
          VcInfo_I(VcId) <= VcInfo_L;
        end if;
      end if;
    end loop;
  end process TmFrameReceive_P;