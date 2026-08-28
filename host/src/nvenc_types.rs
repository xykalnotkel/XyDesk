#[repr(C)]
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct GUID {
    pub Data1: u32,
    pub Data2: u16,
    pub Data3: u16,
    pub Data4: [u8; 8],
}
#[repr(C)]
#[derive(Clone, Copy)]
pub struct NVENC_EXTERNAL_ME_HINT {
    pub bitfieldsMvxMvyRefidxDirParttypeLastofpartLastofmb: i32,
}

impl Default for NVENC_EXTERNAL_ME_HINT {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NVENC_EXTERNAL_ME_HINT_COUNTS_PER_BLOCKTYPE {
    pub bitfieldsNumcandsperblk16X16Numcandsperblk16X8Numcandsperblk8X16Numcandsperblk8X8NumcandspersbReserved:
        u32,
    pub reserved1: [u32; 3],
}

impl Default for NVENC_EXTERNAL_ME_HINT_COUNTS_PER_BLOCKTYPE {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NVENC_EXTERNAL_ME_SB_HINT {
    pub bitfieldsRefidxDirectionBiPartition_TypeX8Last_Of_CuLast_Of_SbReserved0MvxCu_SizeMvyY8Reserved1:
        i16,
}

impl Default for NVENC_EXTERNAL_ME_SB_HINT {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NVENC_RECT {
    pub left: u32,
    pub top: u32,
    pub right: u32,
    pub bottom: u32,
}

impl Default for NVENC_RECT {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENCODE_API_FUNCTION_LIST {
    pub version: u32,
    pub reserved: u32,
    pub nvEncOpenEncodeSession: *mut core::ffi::c_void,
    pub nvEncGetEncodeGUIDCount: *mut core::ffi::c_void,
    pub nvEncGetEncodeProfileGUIDCount: *mut core::ffi::c_void,
    pub nvEncGetEncodeProfileGUIDs: *mut core::ffi::c_void,
    pub nvEncGetEncodeGUIDs: *mut core::ffi::c_void,
    pub nvEncGetInputFormatCount: *mut core::ffi::c_void,
    pub nvEncGetInputFormats: *mut core::ffi::c_void,
    pub nvEncGetEncodeCaps: *mut core::ffi::c_void,
    pub nvEncGetEncodePresetCount: *mut core::ffi::c_void,
    pub nvEncGetEncodePresetGUIDs: *mut core::ffi::c_void,
    pub nvEncGetEncodePresetConfig: *mut core::ffi::c_void,
    pub nvEncInitializeEncoder: *mut core::ffi::c_void,
    pub nvEncCreateInputBuffer: *mut core::ffi::c_void,
    pub nvEncDestroyInputBuffer: *mut core::ffi::c_void,
    pub nvEncCreateBitstreamBuffer: *mut core::ffi::c_void,
    pub nvEncDestroyBitstreamBuffer: *mut core::ffi::c_void,
    pub nvEncEncodePicture: *mut core::ffi::c_void,
    pub nvEncLockBitstream: *mut core::ffi::c_void,
    pub nvEncUnlockBitstream: *mut core::ffi::c_void,
    pub nvEncLockInputBuffer: *mut core::ffi::c_void,
    pub nvEncUnlockInputBuffer: *mut core::ffi::c_void,
    pub nvEncGetEncodeStats: *mut core::ffi::c_void,
    pub nvEncGetSequenceParams: *mut core::ffi::c_void,
    pub nvEncRegisterAsyncEvent: *mut core::ffi::c_void,
    pub nvEncUnregisterAsyncEvent: *mut core::ffi::c_void,
    pub nvEncMapInputResource: *mut core::ffi::c_void,
    pub nvEncUnmapInputResource: *mut core::ffi::c_void,
    pub nvEncDestroyEncoder: *mut core::ffi::c_void,
    pub nvEncInvalidateRefFrames: *mut core::ffi::c_void,
    pub nvEncOpenEncodeSessionEx: *mut core::ffi::c_void,
    pub nvEncRegisterResource: *mut core::ffi::c_void,
    pub nvEncUnregisterResource: *mut core::ffi::c_void,
    pub nvEncReconfigureEncoder: *mut core::ffi::c_void,
    pub reserved1: *mut core::ffi::c_void,
    pub nvEncCreateMVBuffer: *mut core::ffi::c_void,
    pub nvEncDestroyMVBuffer: *mut core::ffi::c_void,
    pub nvEncRunMotionEstimationOnly: *mut core::ffi::c_void,
    pub nvEncGetLastErrorString: *mut core::ffi::c_void,
    pub nvEncSetIOCudaStreams: *mut core::ffi::c_void,
    pub nvEncGetEncodePresetConfigEx: *mut core::ffi::c_void,
    pub nvEncGetSequenceParamEx: *mut core::ffi::c_void,
    pub nvEncRestoreEncoderState: *mut core::ffi::c_void,
    pub nvEncLookaheadPicture: *mut core::ffi::c_void,
    pub reserved2: [*mut core::ffi::c_void; 275],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_CAPS_PARAM {
    pub version: u32,
    pub capsToQuery: u32,
    pub reserved: [u32; 62],
}

impl Default for NV_ENC_CAPS_PARAM {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_CLOCK_TIMESTAMP_SET {
    pub bitfieldsCountingtypeDiscontinuityflagCntdroppedframesNframesSecondsvalueMinutesvalueHoursvalueReserved2:
        u32,
    pub timeOffset: u32,
}

impl Default for NV_ENC_CLOCK_TIMESTAMP_SET {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_CONFIG_AV1 {
    pub level: u32,
    pub tier: u32,
    pub minPartSize: u32,
    pub maxPartSize: u32,
    pub bitfieldsOutputannexbformatEnabletiminginfoEnabledecodermodelinfoEnableframeidnumbersDisableseqhdrRepeatseqhdrEnableintrarefreshChromaformatidcEnablebitstreampaddingEnablecustomtileconfigEnablefilmgrainparamsReserved4Reserved:
        u32,
    pub idrPeriod: u32,
    pub intraRefreshPeriod: u32,
    pub intraRefreshCnt: u32,
    pub maxNumRefFramesInDPB: u32,
    pub numTileColumns: u32,
    pub numTileRows: u32,
    pub reserved2: u32,
    pub tileWidths: *mut u32,
    pub tileHeights: *mut u32,
    pub maxTemporalLayersMinus1: u32,
    pub colorPrimaries: u32,
    pub transferCharacteristics: u32,
    pub matrixCoefficients: u32,
    pub colorRange: u32,
    pub chromaSamplePosition: u32,
    pub useBFramesAsRef: u32,
    pub filmGrainParams: *mut NV_ENC_FILM_GRAIN_PARAMS_AV1,
    pub numFwdRefs: u32,
    pub numBwdRefs: u32,
    pub outputBitDepth: u32,
    pub inputBitDepth: u32,
    pub reserved1: [u32; 233],
    pub reserved3: [*mut core::ffi::c_void; 62],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_CONFIG_H264_MEONLY {
    pub bitfieldsDisablepartition16X16Disablepartition8X16Disablepartition16X8Disablepartition8X8DisableintrasearchBstereoenableReserved:
        u32,
    pub reserved1: [u32; 255],
    pub reserved2: [*mut core::ffi::c_void; 64],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_CONFIG_H264_VUI_PARAMETERS {
    pub overscanInfoPresentFlag: u32,
    pub overscanInfo: u32,
    pub videoSignalTypePresentFlag: u32,
    pub videoFormat: u32,
    pub videoFullRangeFlag: u32,
    pub colourDescriptionPresentFlag: u32,
    pub colourPrimaries: u32,
    pub transferCharacteristics: u32,
    pub colourMatrix: u32,
    pub chromaSampleLocationFlag: u32,
    pub chromaSampleLocationTop: u32,
    pub chromaSampleLocationBot: u32,
    pub bitstreamRestrictionFlag: u32,
    pub timingInfoPresentFlag: u32,
    pub numUnitInTicks: u32,
    pub timeScale: u32,
    pub reserved: [u32; 12],
}

impl Default for NV_ENC_CONFIG_H264_VUI_PARAMETERS {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_CONFIG_HEVC {
    pub level: u32,
    pub tier: u32,
    pub minCUSize: u32,
    pub maxCUSize: u32,
    pub bitfieldsUseconstrainedintrapredDisabledeblockacrosssliceboundaryOutputbufferingperiodseiOutputpicturetimingseiOutputaudEnableltrDisablespsppsRepeatspsppsEnableintrarefreshChromaformatidcReserved3EnablefillerdatainsertionEnableconstrainedencodingEnablealphalayerencodingSinglesliceintrarefreshOutputrecoverypointseiOutputtimecodeseiReserved:
        u32,
    pub idrPeriod: u32,
    pub intraRefreshPeriod: u32,
    pub intraRefreshCnt: u32,
    pub maxNumRefFramesInDPB: u32,
    pub ltrNumFrames: u32,
    pub vpsId: u32,
    pub spsId: u32,
    pub ppsId: u32,
    pub sliceMode: u32,
    pub sliceModeData: u32,
    pub maxTemporalLayersMinus1: u32,
    pub hevcVUIParameters: NV_ENC_CONFIG_H264_VUI_PARAMETERS,
    pub ltrTrustMode: u32,
    pub useBFramesAsRef: u32,
    pub numRefL0: u32,
    pub numRefL1: u32,
    pub tfLevel: u32,
    pub disableDeblockingFilterIDC: u32,
    pub outputBitDepth: u32,
    pub inputBitDepth: u32,
    pub reserved1: [u32; 210],
    pub reserved2: [*mut core::ffi::c_void; 64],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_CONFIG_HEVC_MEONLY {
    pub reserved: [u32; 256],
    pub reserved1: [*mut core::ffi::c_void; 64],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_CREATE_BITSTREAM_BUFFER {
    pub version: u32,
    pub size: u32,
    pub memoryHeap: u32,
    pub reserved: u32,
    pub bitstreamBuffer: *mut core::ffi::c_void,
    pub bitstreamBufferPtr: *mut core::ffi::c_void,
    pub reserved1: [u32; 58],
    pub reserved2: [*mut core::ffi::c_void; 64],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_CREATE_INPUT_BUFFER {
    pub version: u32,
    pub width: u32,
    pub height: u32,
    pub memoryHeap: u32,
    pub bufferFmt: u32,
    pub reserved: u32,
    pub inputBuffer: *mut core::ffi::c_void,
    pub pSysMemBuffer: *mut core::ffi::c_void,
    pub reserved1: [u32; 58],
    pub reserved2: [*mut core::ffi::c_void; 63],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_CREATE_MV_BUFFER {
    pub version: u32,
    pub reserved: u32,
    pub mvBuffer: *mut core::ffi::c_void,
    pub reserved1: [u32; 254],
    pub reserved2: [*mut core::ffi::c_void; 63],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_ENCODE_OUT_PARAMS {
    pub version: u32,
    pub bitstreamSizeInBytes: u32,
    pub reserved: [u32; 62],
}

impl Default for NV_ENC_ENCODE_OUT_PARAMS {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_EVENT_PARAMS {
    pub version: u32,
    pub reserved: u32,
    pub completionEvent: *mut core::ffi::c_void,
    pub reserved1: [u32; 254],
    pub reserved2: [*mut core::ffi::c_void; 64],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_FENCE_POINT_D3D12 {
    pub version: u32,
    pub reserved: u32,
    pub pFence: *mut core::ffi::c_void,
    pub waitValue: u64,
    pub signalValue: u64,
    pub bitfieldsBwaitBsignalReservedbitfield: u32,
    pub reserved1: [u32; 7],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_FILM_GRAIN_PARAMS_AV1 {
    pub bitfieldsApplygrainChromascalingfromlumaOverlapflagCliptorestrictedrangeGrainscalingminus8ArcoefflagNumypointsNumcbpointsNumcrpointsArcoeffshiftminus6GrainscaleshiftReserved1:
        u32,
    pub pointYValue: [u8; 14],
    pub pointYScaling: [u8; 14],
    pub pointCbValue: [u8; 10],
    pub pointCbScaling: [u8; 10],
    pub pointCrValue: [u8; 10],
    pub pointCrScaling: [u8; 10],
    pub arCoeffsYPlus128: [u8; 24],
    pub arCoeffsCbPlus128: [u8; 25],
    pub arCoeffsCrPlus128: [u8; 25],
    pub reserved2: [u8; 2],
    pub cbMult: u8,
    pub cbLumaMult: u8,
    pub cbOffset: u16,
    pub crMult: u8,
    pub crLumaMult: u8,
    pub crOffset: u16,
}

impl Default for NV_ENC_FILM_GRAIN_PARAMS_AV1 {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_INITIALIZE_PARAMS {
    pub version: u32,
    pub encodeGUID: GUID,
    pub presetGUID: GUID,
    pub encodeWidth: u32,
    pub encodeHeight: u32,
    pub darWidth: u32,
    pub darHeight: u32,
    pub frameRateNum: u32,
    pub frameRateDen: u32,
    pub enableEncodeAsync: u32,
    pub enablePTD: u32,
    pub bitfieldsReportsliceoffsetsEnablesubframewriteEnableexternalmehintsEnablemeonlymodeEnableweightedpredictionSplitencodemodeEnableoutputinvidmemEnablereconframeoutputEnableoutputstatsEnableunidirectionalbReservedbitfields:
        u32,
    pub privDataSize: u32,
    pub reserved: u32,
    pub privData: *mut core::ffi::c_void,
    pub encodeConfig: *mut NV_ENC_CONFIG,
    pub maxEncodeWidth: u32,
    pub maxEncodeHeight: u32,
    pub maxMEHintCountsPerBlock: [NVENC_EXTERNAL_ME_HINT_COUNTS_PER_BLOCKTYPE; 2],
    pub tuningInfo: u32,
    pub bufferFormat: u32,
    pub numStateBuffers: u32,
    pub outputStatsLevel: u32,
    pub reserved1: [u32; 284],
    pub reserved2: [*mut core::ffi::c_void; 64],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_INPUT_RESOURCE_D3D12 {
    pub version: u32,
    pub reserved: u32,
    pub pInputBuffer: *mut core::ffi::c_void,
    pub inputFencePoint: NV_ENC_FENCE_POINT_D3D12,
    pub reserved1: [u32; 16],
    pub reserved2: [*mut core::ffi::c_void; 16],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_INPUT_RESOURCE_OPENGL_TEX {
    pub texture: u32,
    pub target: u32,
}

impl Default for NV_ENC_INPUT_RESOURCE_OPENGL_TEX {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_LOCK_BITSTREAM {
    pub version: u32,
    pub bitfieldsDonotwaitLtrframeGetrcstatsReservedbitfields: u32,
    pub outputBitstream: *mut core::ffi::c_void,
    pub sliceOffsets: *mut u32,
    pub frameIdx: u32,
    pub hwEncodeStatus: u32,
    pub numSlices: u32,
    pub bitstreamSizeInBytes: u32,
    pub outputTimeStamp: u64,
    pub outputDuration: u64,
    pub bitstreamBufferPtr: *mut core::ffi::c_void,
    pub pictureType: u32,
    pub pictureStruct: u32,
    pub frameAvgQP: u32,
    pub frameSatd: u32,
    pub ltrFrameIdx: u32,
    pub ltrFrameBitmap: u32,
    pub temporalId: u32,
    pub intraMBCount: u32,
    pub interMBCount: u32,
    pub averageMVX: i32,
    pub averageMVY: i32,
    pub alphaLayerSizeInBytes: u32,
    pub outputStatsPtrSize: u32,
    pub reserved: u32,
    pub outputStatsPtr: *mut core::ffi::c_void,
    pub frameIdxDisplay: u32,
    pub reserved1: [u32; 219],
    pub reserved2: [*mut core::ffi::c_void; 63],
    pub reservedInternal: [u32; 8],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_LOCK_INPUT_BUFFER {
    pub version: u32,
    pub bitfieldsDonotwaitReservedbitfields: u32,
    pub inputBuffer: *mut core::ffi::c_void,
    pub bufferDataPtr: *mut core::ffi::c_void,
    pub pitch: u32,
    pub reserved1: [u32; 251],
    pub reserved2: [*mut core::ffi::c_void; 64],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_LOOKAHEAD_PIC_PARAMS {
    pub version: u32,
    pub reserved: u32,
    pub inputBuffer: *mut core::ffi::c_void,
    pub pictureType: u32,
    pub reserved1: [u32; 63],
    pub reserved2: [*mut core::ffi::c_void; 64],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_MAP_INPUT_RESOURCE {
    pub version: u32,
    pub subResourceIndex: u32,
    pub inputResource: *mut core::ffi::c_void,
    pub registeredResource: *mut core::ffi::c_void,
    pub mappedResource: *mut core::ffi::c_void,
    pub mappedBufferFmt: u32,
    pub reserved1: [u32; 251],
    pub reserved2: [*mut core::ffi::c_void; 63],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_MEONLY_PARAMS {
    pub version: u32,
    pub inputWidth: u32,
    pub inputHeight: u32,
    pub reserved: u32,
    pub inputBuffer: *mut core::ffi::c_void,
    pub referenceFrame: *mut core::ffi::c_void,
    pub mvBuffer: *mut core::ffi::c_void,
    pub reserved2: u32,
    pub bufferFmt: u32,
    pub completionEvent: *mut core::ffi::c_void,
    pub viewID: u32,
    pub meHintCountsPerBlock: [NVENC_EXTERNAL_ME_HINT_COUNTS_PER_BLOCKTYPE; 2],
    pub meExternalHints: *mut NVENC_EXTERNAL_ME_HINT,
    pub reserved1: [u32; 241],
    pub reserved3: [*mut core::ffi::c_void; 59],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_MVECTOR {
    pub mvx: i16,
    pub mvy: i16,
}

impl Default for NV_ENC_MVECTOR {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS {
    pub version: u32,
    pub deviceType: u32,
    pub device: *mut core::ffi::c_void,
    pub reserved: *mut core::ffi::c_void,
    pub apiVersion: u32,
    pub reserved1: [u32; 253],
    pub reserved2: [*mut core::ffi::c_void; 64],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_OUTPUT_RESOURCE_D3D12 {
    pub version: u32,
    pub reserved: u32,
    pub pOutputBuffer: *mut core::ffi::c_void,
    pub outputFencePoint: NV_ENC_FENCE_POINT_D3D12,
    pub reserved1: [u32; 16],
    pub reserved2: [*mut core::ffi::c_void; 16],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_OUTPUT_STATS_BLOCK {
    pub version: u32,
    pub QP: u8,
    pub reserved: [u8; 3],
    pub bitcount: u32,
    pub reserved1: [u32; 13],
}

impl Default for NV_ENC_OUTPUT_STATS_BLOCK {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_OUTPUT_STATS_ROW {
    pub version: u32,
    pub QP: u8,
    pub reserved: [u8; 3],
    pub bitcount: u32,
    pub reserved1: [u32; 13],
}

impl Default for NV_ENC_OUTPUT_STATS_ROW {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_PIC_PARAMS_AV1 {
    pub displayPOCSyntax: u32,
    pub refPicFlag: u32,
    pub temporalId: u32,
    pub forceIntraRefreshWithFrameCnt: u32,
    pub bitfieldsGoldenframeflagArfframeflagArf2FrameflagBwdframeflagOverlayframeflagShowexistingframeflagErrorresilientmodeflagTileconfigupdateEnablecustomtileconfigFilmgrainparamsupdateReservedbitfields:
        u32,
    pub numTileColumns: u32,
    pub numTileRows: u32,
    pub reserved: u32,
    pub tileWidths: *mut u32,
    pub tileHeights: *mut u32,
    pub obuPayloadArrayCnt: u32,
    pub reserved1: u32,
    pub obuPayloadArray: *mut core::ffi::c_void,
    pub filmGrainParams: *mut NV_ENC_FILM_GRAIN_PARAMS_AV1,
    pub reserved2: [u32; 246],
    pub reserved3: [*mut core::ffi::c_void; 61],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_PIC_PARAMS_MVC {
    pub version: u32,
    pub viewID: u32,
    pub temporalID: u32,
    pub priorityID: u32,
    pub reserved1: [u32; 12],
    pub reserved2: [*mut core::ffi::c_void; 8],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_QP {
    pub qpInterP: u32,
    pub qpInterB: u32,
    pub qpIntra: u32,
}

impl Default for NV_ENC_QP {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_RC_PARAMS {
    pub version: u32,
    pub rateControlMode: u32,
    pub constQP: NV_ENC_QP,
    pub averageBitRate: u32,
    pub maxBitRate: u32,
    pub vbvBufferSize: u32,
    pub vbvInitialDelay: u32,
    pub bitfieldsEnableminqpEnablemaxqpEnableinitialrcqpEnableaqReservedbitfield1EnablelookaheadDisableiadaptDisablebadaptEnabletemporalaqZeroreorderdelayEnablenonrefpStrictgoptargetAqstrengthEnableextlookaheadReservedbitfields:
        u32,
    pub minQP: NV_ENC_QP,
    pub maxQP: NV_ENC_QP,
    pub initialRCQP: NV_ENC_QP,
    pub temporallayerIdxMask: u32,
    pub temporalLayerQP: [u8; 8],
    pub targetQuality: u8,
    pub targetQualityLSB: u8,
    pub lookaheadDepth: u16,
    pub lowDelayKeyFrameScale: u8,
    pub yDcQPIndexOffset: i8,
    pub uDcQPIndexOffset: i8,
    pub vDcQPIndexOffset: i8,
    pub qpMapMode: u32,
    pub multiPass: u32,
    pub alphaLayerBitrateRatio: u32,
    pub cbQPIndexOffset: i8,
    pub crQPIndexOffset: i8,
    pub reserved2: u16,
    pub lookaheadLevel: u32,
    pub reserved: [u32; 3],
}

impl Default for NV_ENC_RC_PARAMS {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_RECONFIGURE_PARAMS {
    pub version: u32,
    pub reserved: u32,
    pub reInitEncodeParams: NV_ENC_INITIALIZE_PARAMS,
    pub bitfieldsResetencoderForceidrReserved1: u32,
    pub reserved2: u32,
}

impl Default for NV_ENC_RECONFIGURE_PARAMS {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_REGISTER_RESOURCE {
    pub version: u32,
    pub resourceType: u32,
    pub width: u32,
    pub height: u32,
    pub pitch: u32,
    pub subResourceIndex: u32,
    pub resourceToRegister: *mut core::ffi::c_void,
    pub registeredResource: *mut core::ffi::c_void,
    pub bufferFormat: u32,
    pub bufferUsage: u32,
    pub pInputFencePoint: *mut NV_ENC_FENCE_POINT_D3D12,
    pub chromaOffset: [u32; 2],
    pub reserved1: [u32; 246],
    pub reserved2: [*mut core::ffi::c_void; 61],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_RESTORE_ENCODER_STATE_PARAMS {
    pub version: u32,
    pub bufferIdx: u32,
    pub state: u32,
    pub reserved: u32,
    pub outputBitstream: *mut core::ffi::c_void,
    pub completionEvent: *mut core::ffi::c_void,
    pub reserved1: [u32; 64],
    pub reserved2: [*mut core::ffi::c_void; 64],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_SEI_PAYLOAD {
    pub payloadSize: u32,
    pub payloadType: u32,
    pub payload: *mut u8,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_SEQUENCE_PARAM_PAYLOAD {
    pub version: u32,
    pub inBufferSize: u32,
    pub spsId: u32,
    pub ppsId: u32,
    pub spsppsBuffer: *mut core::ffi::c_void,
    pub outSPSPPSPayloadSize: *mut u32,
    pub reserved: [u32; 250],
    pub reserved2: [*mut core::ffi::c_void; 64],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_STAT {
    pub version: u32,
    pub reserved: u32,
    pub outputBitStream: *mut core::ffi::c_void,
    pub bitStreamSize: u32,
    pub picType: u32,
    pub lastValidByteOffset: u32,
    pub sliceOffsets: [u32; 16],
    pub picIdx: u32,
    pub frameAvgQP: u32,
    pub bitfieldsLtrframeReservedbitfields: u32,
    pub ltrFrameIdx: u32,
    pub intraMBCount: u32,
    pub interMBCount: u32,
    pub averageMVX: i32,
    pub averageMVY: i32,
    pub reserved1: [u32; 227],
    pub reserved2: [*mut core::ffi::c_void; 64],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_TIME_CODE {
    pub displayPicStruct: u32,
    pub clockTimestamp: [NV_ENC_CLOCK_TIMESTAMP_SET; 3],
    pub skipClockTimestampInsertion: u32,
}

impl Default for NV_ENC_TIME_CODE {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_CONFIG_H264 {
    pub bitfieldsEnabletemporalsvcEnablestereomvcHierarchicalpframesHierarchicalbframesOutputbufferingperiodseiOutputpicturetimingseiOutputaudDisablespsppsOutputframepackingseiOutputrecoverypointseiEnableintrarefreshEnableconstrainedencodingRepeatspsppsEnablevfrEnableltrQpprimeyzerotransformbypassflagUseconstrainedintrapredEnablefillerdatainsertionDisablesvcprefixnaluEnablescalabilityinfoseiSinglesliceintrarefreshEnabletimecodeReservedbitfields:
        u32,
    pub level: u32,
    pub idrPeriod: u32,
    pub separateColourPlaneFlag: u32,
    pub disableDeblockingFilterIDC: u32,
    pub numTemporalLayers: u32,
    pub spsId: u32,
    pub ppsId: u32,
    pub adaptiveTransformMode: u32,
    pub fmoMode: u32,
    pub bdirectMode: u32,
    pub entropyCodingMode: u32,
    pub stereoMode: u32,
    pub intraRefreshPeriod: u32,
    pub intraRefreshCnt: u32,
    pub maxNumRefFrames: u32,
    pub sliceMode: u32,
    pub sliceModeData: u32,
    pub h264VUIParameters: NV_ENC_CONFIG_H264_VUI_PARAMETERS,
    pub ltrNumFrames: u32,
    pub ltrTrustMode: u32,
    pub chromaFormatIDC: u32,
    pub maxTemporalLayers: u32,
    pub useBFramesAsRef: u32,
    pub numRefL0: u32,
    pub numRefL1: u32,
    pub outputBitDepth: u32,
    pub inputBitDepth: u32,
    pub reserved1: [u32; 265],
    pub reserved2: [*mut core::ffi::c_void; 64],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_H264_MV_DATA {
    pub mv: [NV_ENC_MVECTOR; 4],
    pub mbType: u8,
    pub partitionType: u8,
    pub reserved: u16,
    pub mbCost: u32,
}

impl Default for NV_ENC_H264_MV_DATA {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_HEVC_MV_DATA {
    pub mv: [NV_ENC_MVECTOR; 4],
    pub cuType: u8,
    pub cuSize: u8,
    pub partitionMode: u8,
    pub lastCUInCTB: u8,
}

impl Default for NV_ENC_HEVC_MV_DATA {
    fn default() -> Self {
        unsafe { core::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub union NV_ENC_PIC_PARAMS_H264_EXT {
    pub mvcPicParams: NV_ENC_PIC_PARAMS_MVC,
    pub reserved1: u32,
}

impl Default for NV_ENC_PIC_PARAMS_H264_EXT {
    fn default() -> Self {
        Self { reserved1: 0 }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_PIC_PARAMS_HEVC {
    pub displayPOCSyntax: u32,
    pub refPicFlag: u32,
    pub temporalId: u32,
    pub forceIntraRefreshWithFrameCnt: u32,
    pub bitfieldsConstrainedframeSlicemodedataupdateLtrmarkframeLtruseframesReservedbitfields: u32,
    pub reserved1: u32,
    pub sliceTypeData: *mut u8,
    pub sliceTypeArrayCnt: u32,
    pub sliceMode: u32,
    pub sliceModeData: u32,
    pub ltrMarkFrameIdx: u32,
    pub ltrUseFrameBitmap: u32,
    pub ltrUsageMode: u32,
    pub seiPayloadArrayCnt: u32,
    pub reserved: u32,
    pub seiPayloadArray: *mut NV_ENC_SEI_PAYLOAD,
    pub timeCode: NV_ENC_TIME_CODE,
    pub reserved2: [u32; 236],
    pub reserved3: [*mut core::ffi::c_void; 61],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub union NV_ENC_CODEC_CONFIG {
    pub h264Config: NV_ENC_CONFIG_H264,
    pub hevcConfig: NV_ENC_CONFIG_HEVC,
    pub av1Config: NV_ENC_CONFIG_AV1,
    pub h264MeOnlyConfig: NV_ENC_CONFIG_H264_MEONLY,
    pub hevcMeOnlyConfig: NV_ENC_CONFIG_HEVC_MEONLY,
    pub reserved: u32,
}

impl Default for NV_ENC_CODEC_CONFIG {
    fn default() -> Self {
        Self { reserved: 0 }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_CONFIG {
    pub version: u32,
    pub profileGUID: GUID,
    pub gopLength: u32,
    pub frameIntervalP: i32,
    pub monoChromeEncoding: u32,
    pub frameFieldMode: u32,
    pub mvPrecision: u32,
    pub rcParams: NV_ENC_RC_PARAMS,
    pub encodeCodecConfig: NV_ENC_CODEC_CONFIG,
    pub reserved: [u32; 278],
    pub reserved2: [*mut core::ffi::c_void; 64],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_PIC_PARAMS_H264 {
    pub displayPOCSyntax: u32,
    pub reserved3: u32,
    pub refPicFlag: u32,
    pub colourPlaneId: u32,
    pub forceIntraRefreshWithFrameCnt: u32,
    pub bitfieldsConstrainedframeSlicemodedataupdateLtrmarkframeLtruseframesReservedbitfields: u32,
    pub sliceTypeData: *mut u8,
    pub sliceTypeArrayCnt: u32,
    pub seiPayloadArrayCnt: u32,
    pub seiPayloadArray: *mut NV_ENC_SEI_PAYLOAD,
    pub sliceMode: u32,
    pub sliceModeData: u32,
    pub ltrMarkFrameIdx: u32,
    pub ltrUseFrameBitmap: u32,
    pub ltrUsageMode: u32,
    pub forceIntraSliceCount: u32,
    pub forceIntraSliceIdx: *mut u32,
    pub h264ExtPicParams: NV_ENC_PIC_PARAMS_H264_EXT,
    pub timeCode: NV_ENC_TIME_CODE,
    pub reserved: [u32; 202],
    pub reserved2: [*mut core::ffi::c_void; 61],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_PRESET_CONFIG {
    pub version: u32,
    pub reserved: u32,
    pub presetCfg: NV_ENC_CONFIG,
    pub reserved1: [u32; 256],
    pub reserved2: [*mut core::ffi::c_void; 64],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub union NV_ENC_CODEC_PIC_PARAMS {
    pub h264PicParams: NV_ENC_PIC_PARAMS_H264,
    pub hevcPicParams: NV_ENC_PIC_PARAMS_HEVC,
    pub av1PicParams: NV_ENC_PIC_PARAMS_AV1,
    pub reserved: u32,
}

impl Default for NV_ENC_CODEC_PIC_PARAMS {
    fn default() -> Self {
        Self { reserved: 0 }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct NV_ENC_PIC_PARAMS {
    pub version: u32,
    pub inputWidth: u32,
    pub inputHeight: u32,
    pub inputPitch: u32,
    pub encodePicFlags: u32,
    pub frameIdx: u32,
    pub inputTimeStamp: u64,
    pub inputDuration: u64,
    pub inputBuffer: *mut core::ffi::c_void,
    pub outputBitstream: *mut core::ffi::c_void,
    pub completionEvent: *mut core::ffi::c_void,
    pub bufferFmt: u32,
    pub pictureStruct: u32,
    pub pictureType: u32,
    pub codecPicParams: NV_ENC_CODEC_PIC_PARAMS,
    pub meHintCountsPerBlock: [NVENC_EXTERNAL_ME_HINT_COUNTS_PER_BLOCKTYPE; 2],
    pub meExternalHints: *mut NVENC_EXTERNAL_ME_HINT,
    pub reserved2: [u32; 7],
    pub reserved5: [*mut core::ffi::c_void; 2],
    pub qpDeltaMap: *mut i8,
    pub qpDeltaMapSize: u32,
    pub reservedBitFields: u32,
    pub meHintRefPicDist: [u16; 2],
    pub reserved4: u32,
    pub alphaBuffer: *mut core::ffi::c_void,
    pub meExternalSbHints: *mut NVENC_EXTERNAL_ME_SB_HINT,
    pub meSbHintsCount: u32,
    pub stateBufferIdx: u32,
    pub outputReconBuffer: *mut core::ffi::c_void,
    pub reserved3: [u32; 284],
    pub reserved6: [*mut core::ffi::c_void; 57],
}

#[allow(non_camel_case_types, dead_code, non_snake_case)]
#[cfg(test)]
mod layout_tests {
    use super::*;
    #[test]
    fn layout_matches_c() {
        assert_eq!(
            core::mem::size_of::<NV_ENC_CREATE_INPUT_BUFFER>(),
            776,
            "size NV_ENC_CREATE_INPUT_BUFFER"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_INPUT_BUFFER, version),
            0,
            "offset NV_ENC_CREATE_INPUT_BUFFER.version"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_INPUT_BUFFER, width),
            4,
            "offset NV_ENC_CREATE_INPUT_BUFFER.width"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_INPUT_BUFFER, height),
            8,
            "offset NV_ENC_CREATE_INPUT_BUFFER.height"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_INPUT_BUFFER, memoryHeap),
            12,
            "offset NV_ENC_CREATE_INPUT_BUFFER.memoryHeap"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_INPUT_BUFFER, bufferFmt),
            16,
            "offset NV_ENC_CREATE_INPUT_BUFFER.bufferFmt"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_INPUT_BUFFER, reserved),
            20,
            "offset NV_ENC_CREATE_INPUT_BUFFER.reserved"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_INPUT_BUFFER, inputBuffer),
            24,
            "offset NV_ENC_CREATE_INPUT_BUFFER.inputBuffer"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_INPUT_BUFFER, pSysMemBuffer),
            32,
            "offset NV_ENC_CREATE_INPUT_BUFFER.pSysMemBuffer"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_INPUT_BUFFER, reserved1),
            40,
            "offset NV_ENC_CREATE_INPUT_BUFFER.reserved1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_INPUT_BUFFER, reserved2),
            272,
            "offset NV_ENC_CREATE_INPUT_BUFFER.reserved2"
        );
        assert_eq!(
            core::mem::size_of::<NV_ENC_CREATE_BITSTREAM_BUFFER>(),
            776,
            "size NV_ENC_CREATE_BITSTREAM_BUFFER"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_BITSTREAM_BUFFER, version),
            0,
            "offset NV_ENC_CREATE_BITSTREAM_BUFFER.version"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_BITSTREAM_BUFFER, size),
            4,
            "offset NV_ENC_CREATE_BITSTREAM_BUFFER.size"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_BITSTREAM_BUFFER, memoryHeap),
            8,
            "offset NV_ENC_CREATE_BITSTREAM_BUFFER.memoryHeap"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_BITSTREAM_BUFFER, reserved),
            12,
            "offset NV_ENC_CREATE_BITSTREAM_BUFFER.reserved"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_BITSTREAM_BUFFER, bitstreamBuffer),
            16,
            "offset NV_ENC_CREATE_BITSTREAM_BUFFER.bitstreamBuffer"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_BITSTREAM_BUFFER, bitstreamBufferPtr),
            24,
            "offset NV_ENC_CREATE_BITSTREAM_BUFFER.bitstreamBufferPtr"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_BITSTREAM_BUFFER, reserved1),
            32,
            "offset NV_ENC_CREATE_BITSTREAM_BUFFER.reserved1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CREATE_BITSTREAM_BUFFER, reserved2),
            264,
            "offset NV_ENC_CREATE_BITSTREAM_BUFFER.reserved2"
        );
        assert_eq!(
            core::mem::size_of::<NV_ENC_RC_PARAMS>(),
            128,
            "size NV_ENC_RC_PARAMS"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, version),
            0,
            "offset NV_ENC_RC_PARAMS.version"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, rateControlMode),
            4,
            "offset NV_ENC_RC_PARAMS.rateControlMode"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, constQP),
            8,
            "offset NV_ENC_RC_PARAMS.constQP"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, averageBitRate),
            20,
            "offset NV_ENC_RC_PARAMS.averageBitRate"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, maxBitRate),
            24,
            "offset NV_ENC_RC_PARAMS.maxBitRate"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, vbvBufferSize),
            28,
            "offset NV_ENC_RC_PARAMS.vbvBufferSize"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, vbvInitialDelay),
            32,
            "offset NV_ENC_RC_PARAMS.vbvInitialDelay"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, minQP),
            40,
            "offset NV_ENC_RC_PARAMS.minQP"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, maxQP),
            52,
            "offset NV_ENC_RC_PARAMS.maxQP"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, initialRCQP),
            64,
            "offset NV_ENC_RC_PARAMS.initialRCQP"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, temporallayerIdxMask),
            76,
            "offset NV_ENC_RC_PARAMS.temporallayerIdxMask"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, temporalLayerQP),
            80,
            "offset NV_ENC_RC_PARAMS.temporalLayerQP"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, targetQuality),
            88,
            "offset NV_ENC_RC_PARAMS.targetQuality"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, targetQualityLSB),
            89,
            "offset NV_ENC_RC_PARAMS.targetQualityLSB"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, lookaheadDepth),
            90,
            "offset NV_ENC_RC_PARAMS.lookaheadDepth"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, lowDelayKeyFrameScale),
            92,
            "offset NV_ENC_RC_PARAMS.lowDelayKeyFrameScale"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, yDcQPIndexOffset),
            93,
            "offset NV_ENC_RC_PARAMS.yDcQPIndexOffset"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, uDcQPIndexOffset),
            94,
            "offset NV_ENC_RC_PARAMS.uDcQPIndexOffset"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, vDcQPIndexOffset),
            95,
            "offset NV_ENC_RC_PARAMS.vDcQPIndexOffset"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, qpMapMode),
            96,
            "offset NV_ENC_RC_PARAMS.qpMapMode"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, multiPass),
            100,
            "offset NV_ENC_RC_PARAMS.multiPass"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, alphaLayerBitrateRatio),
            104,
            "offset NV_ENC_RC_PARAMS.alphaLayerBitrateRatio"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, cbQPIndexOffset),
            108,
            "offset NV_ENC_RC_PARAMS.cbQPIndexOffset"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, crQPIndexOffset),
            109,
            "offset NV_ENC_RC_PARAMS.crQPIndexOffset"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, reserved2),
            110,
            "offset NV_ENC_RC_PARAMS.reserved2"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, lookaheadLevel),
            112,
            "offset NV_ENC_RC_PARAMS.lookaheadLevel"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_RC_PARAMS, reserved),
            116,
            "offset NV_ENC_RC_PARAMS.reserved"
        );
        assert_eq!(
            core::mem::size_of::<NV_ENC_CONFIG_H264_VUI_PARAMETERS>(),
            112,
            "size NV_ENC_CONFIG_H264_VUI_PARAMETERS"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264_VUI_PARAMETERS, overscanInfoPresentFlag),
            0,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.overscanInfoPresentFlag"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264_VUI_PARAMETERS, overscanInfo),
            4,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.overscanInfo"
        );
        assert_eq!(
            core::mem::offset_of!(
                NV_ENC_CONFIG_H264_VUI_PARAMETERS,
                videoSignalTypePresentFlag
            ),
            8,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.videoSignalTypePresentFlag"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264_VUI_PARAMETERS, videoFormat),
            12,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.videoFormat"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264_VUI_PARAMETERS, videoFullRangeFlag),
            16,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.videoFullRangeFlag"
        );
        assert_eq!(
            core::mem::offset_of!(
                NV_ENC_CONFIG_H264_VUI_PARAMETERS,
                colourDescriptionPresentFlag
            ),
            20,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.colourDescriptionPresentFlag"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264_VUI_PARAMETERS, colourPrimaries),
            24,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.colourPrimaries"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264_VUI_PARAMETERS, transferCharacteristics),
            28,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.transferCharacteristics"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264_VUI_PARAMETERS, colourMatrix),
            32,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.colourMatrix"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264_VUI_PARAMETERS, chromaSampleLocationFlag),
            36,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.chromaSampleLocationFlag"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264_VUI_PARAMETERS, chromaSampleLocationTop),
            40,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.chromaSampleLocationTop"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264_VUI_PARAMETERS, chromaSampleLocationBot),
            44,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.chromaSampleLocationBot"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264_VUI_PARAMETERS, bitstreamRestrictionFlag),
            48,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.bitstreamRestrictionFlag"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264_VUI_PARAMETERS, timingInfoPresentFlag),
            52,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.timingInfoPresentFlag"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264_VUI_PARAMETERS, numUnitInTicks),
            56,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.numUnitInTicks"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264_VUI_PARAMETERS, timeScale),
            60,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.timeScale"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264_VUI_PARAMETERS, reserved),
            64,
            "offset NV_ENC_CONFIG_H264_VUI_PARAMETERS.reserved"
        );
        assert_eq!(
            core::mem::size_of::<NV_ENC_CONFIG_H264>(),
            1792,
            "size NV_ENC_CONFIG_H264"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, level),
            4,
            "offset NV_ENC_CONFIG_H264.level"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, idrPeriod),
            8,
            "offset NV_ENC_CONFIG_H264.idrPeriod"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, separateColourPlaneFlag),
            12,
            "offset NV_ENC_CONFIG_H264.separateColourPlaneFlag"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, disableDeblockingFilterIDC),
            16,
            "offset NV_ENC_CONFIG_H264.disableDeblockingFilterIDC"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, numTemporalLayers),
            20,
            "offset NV_ENC_CONFIG_H264.numTemporalLayers"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, spsId),
            24,
            "offset NV_ENC_CONFIG_H264.spsId"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, ppsId),
            28,
            "offset NV_ENC_CONFIG_H264.ppsId"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, adaptiveTransformMode),
            32,
            "offset NV_ENC_CONFIG_H264.adaptiveTransformMode"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, fmoMode),
            36,
            "offset NV_ENC_CONFIG_H264.fmoMode"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, bdirectMode),
            40,
            "offset NV_ENC_CONFIG_H264.bdirectMode"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, entropyCodingMode),
            44,
            "offset NV_ENC_CONFIG_H264.entropyCodingMode"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, stereoMode),
            48,
            "offset NV_ENC_CONFIG_H264.stereoMode"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, intraRefreshPeriod),
            52,
            "offset NV_ENC_CONFIG_H264.intraRefreshPeriod"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, intraRefreshCnt),
            56,
            "offset NV_ENC_CONFIG_H264.intraRefreshCnt"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, maxNumRefFrames),
            60,
            "offset NV_ENC_CONFIG_H264.maxNumRefFrames"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, sliceMode),
            64,
            "offset NV_ENC_CONFIG_H264.sliceMode"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, sliceModeData),
            68,
            "offset NV_ENC_CONFIG_H264.sliceModeData"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, h264VUIParameters),
            72,
            "offset NV_ENC_CONFIG_H264.h264VUIParameters"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, ltrNumFrames),
            184,
            "offset NV_ENC_CONFIG_H264.ltrNumFrames"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, ltrTrustMode),
            188,
            "offset NV_ENC_CONFIG_H264.ltrTrustMode"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, chromaFormatIDC),
            192,
            "offset NV_ENC_CONFIG_H264.chromaFormatIDC"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, maxTemporalLayers),
            196,
            "offset NV_ENC_CONFIG_H264.maxTemporalLayers"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, useBFramesAsRef),
            200,
            "offset NV_ENC_CONFIG_H264.useBFramesAsRef"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, numRefL0),
            204,
            "offset NV_ENC_CONFIG_H264.numRefL0"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, numRefL1),
            208,
            "offset NV_ENC_CONFIG_H264.numRefL1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, outputBitDepth),
            212,
            "offset NV_ENC_CONFIG_H264.outputBitDepth"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, inputBitDepth),
            216,
            "offset NV_ENC_CONFIG_H264.inputBitDepth"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, reserved1),
            220,
            "offset NV_ENC_CONFIG_H264.reserved1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_H264, reserved2),
            1280,
            "offset NV_ENC_CONFIG_H264.reserved2"
        );
        assert_eq!(
            core::mem::size_of::<NV_ENC_CONFIG_HEVC>(),
            1560,
            "size NV_ENC_CONFIG_HEVC"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, level),
            0,
            "offset NV_ENC_CONFIG_HEVC.level"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, tier),
            4,
            "offset NV_ENC_CONFIG_HEVC.tier"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, minCUSize),
            8,
            "offset NV_ENC_CONFIG_HEVC.minCUSize"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, maxCUSize),
            12,
            "offset NV_ENC_CONFIG_HEVC.maxCUSize"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, idrPeriod),
            20,
            "offset NV_ENC_CONFIG_HEVC.idrPeriod"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, intraRefreshPeriod),
            24,
            "offset NV_ENC_CONFIG_HEVC.intraRefreshPeriod"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, intraRefreshCnt),
            28,
            "offset NV_ENC_CONFIG_HEVC.intraRefreshCnt"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, maxNumRefFramesInDPB),
            32,
            "offset NV_ENC_CONFIG_HEVC.maxNumRefFramesInDPB"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, ltrNumFrames),
            36,
            "offset NV_ENC_CONFIG_HEVC.ltrNumFrames"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, vpsId),
            40,
            "offset NV_ENC_CONFIG_HEVC.vpsId"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, spsId),
            44,
            "offset NV_ENC_CONFIG_HEVC.spsId"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, ppsId),
            48,
            "offset NV_ENC_CONFIG_HEVC.ppsId"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, sliceMode),
            52,
            "offset NV_ENC_CONFIG_HEVC.sliceMode"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, sliceModeData),
            56,
            "offset NV_ENC_CONFIG_HEVC.sliceModeData"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, maxTemporalLayersMinus1),
            60,
            "offset NV_ENC_CONFIG_HEVC.maxTemporalLayersMinus1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, hevcVUIParameters),
            64,
            "offset NV_ENC_CONFIG_HEVC.hevcVUIParameters"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, ltrTrustMode),
            176,
            "offset NV_ENC_CONFIG_HEVC.ltrTrustMode"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, useBFramesAsRef),
            180,
            "offset NV_ENC_CONFIG_HEVC.useBFramesAsRef"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, numRefL0),
            184,
            "offset NV_ENC_CONFIG_HEVC.numRefL0"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, numRefL1),
            188,
            "offset NV_ENC_CONFIG_HEVC.numRefL1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, tfLevel),
            192,
            "offset NV_ENC_CONFIG_HEVC.tfLevel"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, disableDeblockingFilterIDC),
            196,
            "offset NV_ENC_CONFIG_HEVC.disableDeblockingFilterIDC"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, outputBitDepth),
            200,
            "offset NV_ENC_CONFIG_HEVC.outputBitDepth"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, inputBitDepth),
            204,
            "offset NV_ENC_CONFIG_HEVC.inputBitDepth"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, reserved1),
            208,
            "offset NV_ENC_CONFIG_HEVC.reserved1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_HEVC, reserved2),
            1048,
            "offset NV_ENC_CONFIG_HEVC.reserved2"
        );
        assert_eq!(
            core::mem::size_of::<NV_ENC_CONFIG_AV1>(),
            1552,
            "size NV_ENC_CONFIG_AV1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, level),
            0,
            "offset NV_ENC_CONFIG_AV1.level"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, tier),
            4,
            "offset NV_ENC_CONFIG_AV1.tier"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, minPartSize),
            8,
            "offset NV_ENC_CONFIG_AV1.minPartSize"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, maxPartSize),
            12,
            "offset NV_ENC_CONFIG_AV1.maxPartSize"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, idrPeriod),
            20,
            "offset NV_ENC_CONFIG_AV1.idrPeriod"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, intraRefreshPeriod),
            24,
            "offset NV_ENC_CONFIG_AV1.intraRefreshPeriod"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, intraRefreshCnt),
            28,
            "offset NV_ENC_CONFIG_AV1.intraRefreshCnt"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, maxNumRefFramesInDPB),
            32,
            "offset NV_ENC_CONFIG_AV1.maxNumRefFramesInDPB"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, numTileColumns),
            36,
            "offset NV_ENC_CONFIG_AV1.numTileColumns"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, numTileRows),
            40,
            "offset NV_ENC_CONFIG_AV1.numTileRows"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, reserved2),
            44,
            "offset NV_ENC_CONFIG_AV1.reserved2"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, maxTemporalLayersMinus1),
            64,
            "offset NV_ENC_CONFIG_AV1.maxTemporalLayersMinus1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, colorPrimaries),
            68,
            "offset NV_ENC_CONFIG_AV1.colorPrimaries"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, transferCharacteristics),
            72,
            "offset NV_ENC_CONFIG_AV1.transferCharacteristics"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, matrixCoefficients),
            76,
            "offset NV_ENC_CONFIG_AV1.matrixCoefficients"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, colorRange),
            80,
            "offset NV_ENC_CONFIG_AV1.colorRange"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, chromaSamplePosition),
            84,
            "offset NV_ENC_CONFIG_AV1.chromaSamplePosition"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, useBFramesAsRef),
            88,
            "offset NV_ENC_CONFIG_AV1.useBFramesAsRef"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, numFwdRefs),
            104,
            "offset NV_ENC_CONFIG_AV1.numFwdRefs"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, numBwdRefs),
            108,
            "offset NV_ENC_CONFIG_AV1.numBwdRefs"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, outputBitDepth),
            112,
            "offset NV_ENC_CONFIG_AV1.outputBitDepth"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, inputBitDepth),
            116,
            "offset NV_ENC_CONFIG_AV1.inputBitDepth"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, reserved1),
            120,
            "offset NV_ENC_CONFIG_AV1.reserved1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG_AV1, reserved3),
            1056,
            "offset NV_ENC_CONFIG_AV1.reserved3"
        );
        assert_eq!(
            core::mem::size_of::<NV_ENC_CONFIG>(),
            3584,
            "size NV_ENC_CONFIG"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG, version),
            0,
            "offset NV_ENC_CONFIG.version"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG, profileGUID),
            4,
            "offset NV_ENC_CONFIG.profileGUID"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG, gopLength),
            20,
            "offset NV_ENC_CONFIG.gopLength"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG, frameIntervalP),
            24,
            "offset NV_ENC_CONFIG.frameIntervalP"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG, monoChromeEncoding),
            28,
            "offset NV_ENC_CONFIG.monoChromeEncoding"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG, frameFieldMode),
            32,
            "offset NV_ENC_CONFIG.frameFieldMode"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG, mvPrecision),
            36,
            "offset NV_ENC_CONFIG.mvPrecision"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG, rcParams),
            40,
            "offset NV_ENC_CONFIG.rcParams"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG, encodeCodecConfig),
            168,
            "offset NV_ENC_CONFIG.encodeCodecConfig"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG, reserved),
            1960,
            "offset NV_ENC_CONFIG.reserved"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_CONFIG, reserved2),
            3072,
            "offset NV_ENC_CONFIG.reserved2"
        );
        assert_eq!(
            core::mem::size_of::<NV_ENC_INITIALIZE_PARAMS>(),
            1800,
            "size NV_ENC_INITIALIZE_PARAMS"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, version),
            0,
            "offset NV_ENC_INITIALIZE_PARAMS.version"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, encodeGUID),
            4,
            "offset NV_ENC_INITIALIZE_PARAMS.encodeGUID"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, presetGUID),
            20,
            "offset NV_ENC_INITIALIZE_PARAMS.presetGUID"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, encodeWidth),
            36,
            "offset NV_ENC_INITIALIZE_PARAMS.encodeWidth"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, encodeHeight),
            40,
            "offset NV_ENC_INITIALIZE_PARAMS.encodeHeight"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, darWidth),
            44,
            "offset NV_ENC_INITIALIZE_PARAMS.darWidth"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, darHeight),
            48,
            "offset NV_ENC_INITIALIZE_PARAMS.darHeight"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, frameRateNum),
            52,
            "offset NV_ENC_INITIALIZE_PARAMS.frameRateNum"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, frameRateDen),
            56,
            "offset NV_ENC_INITIALIZE_PARAMS.frameRateDen"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, enableEncodeAsync),
            60,
            "offset NV_ENC_INITIALIZE_PARAMS.enableEncodeAsync"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, enablePTD),
            64,
            "offset NV_ENC_INITIALIZE_PARAMS.enablePTD"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, privDataSize),
            72,
            "offset NV_ENC_INITIALIZE_PARAMS.privDataSize"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, reserved),
            76,
            "offset NV_ENC_INITIALIZE_PARAMS.reserved"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, privData),
            80,
            "offset NV_ENC_INITIALIZE_PARAMS.privData"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, encodeConfig),
            88,
            "offset NV_ENC_INITIALIZE_PARAMS.encodeConfig"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, maxEncodeWidth),
            96,
            "offset NV_ENC_INITIALIZE_PARAMS.maxEncodeWidth"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, maxEncodeHeight),
            100,
            "offset NV_ENC_INITIALIZE_PARAMS.maxEncodeHeight"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, maxMEHintCountsPerBlock),
            104,
            "offset NV_ENC_INITIALIZE_PARAMS.maxMEHintCountsPerBlock"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, tuningInfo),
            136,
            "offset NV_ENC_INITIALIZE_PARAMS.tuningInfo"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, bufferFormat),
            140,
            "offset NV_ENC_INITIALIZE_PARAMS.bufferFormat"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, numStateBuffers),
            144,
            "offset NV_ENC_INITIALIZE_PARAMS.numStateBuffers"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, outputStatsLevel),
            148,
            "offset NV_ENC_INITIALIZE_PARAMS.outputStatsLevel"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, reserved1),
            152,
            "offset NV_ENC_INITIALIZE_PARAMS.reserved1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_INITIALIZE_PARAMS, reserved2),
            1288,
            "offset NV_ENC_INITIALIZE_PARAMS.reserved2"
        );
        assert_eq!(
            core::mem::size_of::<NV_ENC_PRESET_CONFIG>(),
            5128,
            "size NV_ENC_PRESET_CONFIG"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_PRESET_CONFIG, version),
            0,
            "offset NV_ENC_PRESET_CONFIG.version"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_PRESET_CONFIG, reserved),
            4,
            "offset NV_ENC_PRESET_CONFIG.reserved"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_PRESET_CONFIG, presetCfg),
            8,
            "offset NV_ENC_PRESET_CONFIG.presetCfg"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_PRESET_CONFIG, reserved1),
            3592,
            "offset NV_ENC_PRESET_CONFIG.reserved1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_PRESET_CONFIG, reserved2),
            4616,
            "offset NV_ENC_PRESET_CONFIG.reserved2"
        );
        assert_eq!(
            core::mem::size_of::<NV_ENC_MAP_INPUT_RESOURCE>(),
            1544,
            "size NV_ENC_MAP_INPUT_RESOURCE"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_MAP_INPUT_RESOURCE, version),
            0,
            "offset NV_ENC_MAP_INPUT_RESOURCE.version"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_MAP_INPUT_RESOURCE, subResourceIndex),
            4,
            "offset NV_ENC_MAP_INPUT_RESOURCE.subResourceIndex"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_MAP_INPUT_RESOURCE, inputResource),
            8,
            "offset NV_ENC_MAP_INPUT_RESOURCE.inputResource"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_MAP_INPUT_RESOURCE, registeredResource),
            16,
            "offset NV_ENC_MAP_INPUT_RESOURCE.registeredResource"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_MAP_INPUT_RESOURCE, mappedResource),
            24,
            "offset NV_ENC_MAP_INPUT_RESOURCE.mappedResource"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_MAP_INPUT_RESOURCE, mappedBufferFmt),
            32,
            "offset NV_ENC_MAP_INPUT_RESOURCE.mappedBufferFmt"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_MAP_INPUT_RESOURCE, reserved1),
            36,
            "offset NV_ENC_MAP_INPUT_RESOURCE.reserved1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_MAP_INPUT_RESOURCE, reserved2),
            1040,
            "offset NV_ENC_MAP_INPUT_RESOURCE.reserved2"
        );
        assert_eq!(
            core::mem::size_of::<NV_ENC_REGISTER_RESOURCE>(),
            1536,
            "size NV_ENC_REGISTER_RESOURCE"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_REGISTER_RESOURCE, version),
            0,
            "offset NV_ENC_REGISTER_RESOURCE.version"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_REGISTER_RESOURCE, resourceType),
            4,
            "offset NV_ENC_REGISTER_RESOURCE.resourceType"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_REGISTER_RESOURCE, width),
            8,
            "offset NV_ENC_REGISTER_RESOURCE.width"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_REGISTER_RESOURCE, height),
            12,
            "offset NV_ENC_REGISTER_RESOURCE.height"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_REGISTER_RESOURCE, pitch),
            16,
            "offset NV_ENC_REGISTER_RESOURCE.pitch"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_REGISTER_RESOURCE, subResourceIndex),
            20,
            "offset NV_ENC_REGISTER_RESOURCE.subResourceIndex"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_REGISTER_RESOURCE, resourceToRegister),
            24,
            "offset NV_ENC_REGISTER_RESOURCE.resourceToRegister"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_REGISTER_RESOURCE, registeredResource),
            32,
            "offset NV_ENC_REGISTER_RESOURCE.registeredResource"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_REGISTER_RESOURCE, bufferFormat),
            40,
            "offset NV_ENC_REGISTER_RESOURCE.bufferFormat"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_REGISTER_RESOURCE, bufferUsage),
            44,
            "offset NV_ENC_REGISTER_RESOURCE.bufferUsage"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_REGISTER_RESOURCE, pInputFencePoint),
            48,
            "offset NV_ENC_REGISTER_RESOURCE.pInputFencePoint"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_REGISTER_RESOURCE, chromaOffset),
            56,
            "offset NV_ENC_REGISTER_RESOURCE.chromaOffset"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_REGISTER_RESOURCE, reserved1),
            64,
            "offset NV_ENC_REGISTER_RESOURCE.reserved1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_REGISTER_RESOURCE, reserved2),
            1048,
            "offset NV_ENC_REGISTER_RESOURCE.reserved2"
        );
        assert_eq!(
            core::mem::size_of::<NV_ENC_LOCK_BITSTREAM>(),
            1544,
            "size NV_ENC_LOCK_BITSTREAM"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, version),
            0,
            "offset NV_ENC_LOCK_BITSTREAM.version"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, outputBitstream),
            8,
            "offset NV_ENC_LOCK_BITSTREAM.outputBitstream"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, sliceOffsets),
            16,
            "offset NV_ENC_LOCK_BITSTREAM.sliceOffsets"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, frameIdx),
            24,
            "offset NV_ENC_LOCK_BITSTREAM.frameIdx"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, hwEncodeStatus),
            28,
            "offset NV_ENC_LOCK_BITSTREAM.hwEncodeStatus"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, numSlices),
            32,
            "offset NV_ENC_LOCK_BITSTREAM.numSlices"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, bitstreamSizeInBytes),
            36,
            "offset NV_ENC_LOCK_BITSTREAM.bitstreamSizeInBytes"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, outputTimeStamp),
            40,
            "offset NV_ENC_LOCK_BITSTREAM.outputTimeStamp"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, outputDuration),
            48,
            "offset NV_ENC_LOCK_BITSTREAM.outputDuration"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, bitstreamBufferPtr),
            56,
            "offset NV_ENC_LOCK_BITSTREAM.bitstreamBufferPtr"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, pictureType),
            64,
            "offset NV_ENC_LOCK_BITSTREAM.pictureType"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, pictureStruct),
            68,
            "offset NV_ENC_LOCK_BITSTREAM.pictureStruct"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, frameAvgQP),
            72,
            "offset NV_ENC_LOCK_BITSTREAM.frameAvgQP"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, frameSatd),
            76,
            "offset NV_ENC_LOCK_BITSTREAM.frameSatd"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, ltrFrameIdx),
            80,
            "offset NV_ENC_LOCK_BITSTREAM.ltrFrameIdx"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, ltrFrameBitmap),
            84,
            "offset NV_ENC_LOCK_BITSTREAM.ltrFrameBitmap"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, temporalId),
            88,
            "offset NV_ENC_LOCK_BITSTREAM.temporalId"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, intraMBCount),
            92,
            "offset NV_ENC_LOCK_BITSTREAM.intraMBCount"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, interMBCount),
            96,
            "offset NV_ENC_LOCK_BITSTREAM.interMBCount"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, averageMVX),
            100,
            "offset NV_ENC_LOCK_BITSTREAM.averageMVX"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, averageMVY),
            104,
            "offset NV_ENC_LOCK_BITSTREAM.averageMVY"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, alphaLayerSizeInBytes),
            108,
            "offset NV_ENC_LOCK_BITSTREAM.alphaLayerSizeInBytes"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, outputStatsPtrSize),
            112,
            "offset NV_ENC_LOCK_BITSTREAM.outputStatsPtrSize"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, reserved),
            116,
            "offset NV_ENC_LOCK_BITSTREAM.reserved"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, outputStatsPtr),
            120,
            "offset NV_ENC_LOCK_BITSTREAM.outputStatsPtr"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, frameIdxDisplay),
            128,
            "offset NV_ENC_LOCK_BITSTREAM.frameIdxDisplay"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, reserved1),
            132,
            "offset NV_ENC_LOCK_BITSTREAM.reserved1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, reserved2),
            1008,
            "offset NV_ENC_LOCK_BITSTREAM.reserved2"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_LOCK_BITSTREAM, reservedInternal),
            1512,
            "offset NV_ENC_LOCK_BITSTREAM.reservedInternal"
        );
        assert_eq!(
            core::mem::size_of::<NV_ENC_SEI_PAYLOAD>(),
            16,
            "size NV_ENC_SEI_PAYLOAD"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_SEI_PAYLOAD, payloadSize),
            0,
            "offset NV_ENC_SEI_PAYLOAD.payloadSize"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_SEI_PAYLOAD, payloadType),
            4,
            "offset NV_ENC_SEI_PAYLOAD.payloadType"
        );
        assert_eq!(core::mem::size_of::<NV_ENC_QP>(), 12, "size NV_ENC_QP");
        assert_eq!(
            core::mem::offset_of!(NV_ENC_QP, qpInterP),
            0,
            "offset NV_ENC_QP.qpInterP"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_QP, qpInterB),
            4,
            "offset NV_ENC_QP.qpInterB"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_QP, qpIntra),
            8,
            "offset NV_ENC_QP.qpIntra"
        );
        assert_eq!(
            core::mem::size_of::<NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS>(),
            1552,
            "size NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS, version),
            0,
            "offset NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS.version"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS, deviceType),
            4,
            "offset NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS.deviceType"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS, device),
            8,
            "offset NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS.device"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS, reserved),
            16,
            "offset NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS.reserved"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS, apiVersion),
            24,
            "offset NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS.apiVersion"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS, reserved1),
            28,
            "offset NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS.reserved1"
        );
        assert_eq!(
            core::mem::offset_of!(NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS, reserved2),
            1040,
            "offset NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS.reserved2"
        );
    }
}
