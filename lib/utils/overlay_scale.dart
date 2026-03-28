/// 프리뷰와 내보내기에서 동일한 비율로 fontSize/패딩을 스케일링하기 위한 기준 높이.
///
/// 프리뷰: scale = previewHeight / kReferenceHeight
/// 내보내기: scale = videoResolution.height / kReferenceHeight
const double kReferenceHeight = 800.0;

double overlayScale(double actualHeight) => actualHeight / kReferenceHeight;
