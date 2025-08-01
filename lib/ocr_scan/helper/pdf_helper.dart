import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

class PDFHelper {
  static Future<ImagePDF?> convertToPDFImage(PdfDocument document) async {
    img.Image? image = await _createFullImageFromPDF(document);
    if (image == null) {
      return null;
    }

    File? file = await _imageToFile(image);
    if (file == null) {
      return null;
    }

    return ImagePDF(
      document: document,
      file: file,
      image: image,
    );
  }

  static Future<img.Image?> _createFullImageFromPDF(
      PdfDocument document) async {
    final List<img.Image> imageList = [];
    int height = 0, width = 0;

    /// On prend que les 2 premiers page max, sinon c'est le bordel
    for (int i = 1; i <= min(2, document.pages.length); i++) {
      final page = document.pages[i];
      // 5 is an arbitrary number, we enlarge the image to improve text detection
      int scaleUp = 5;
      final pageImage = await page.render(
        width: page.width.toInt() * scaleUp,
        height: page.height.toInt() * scaleUp,
        fullWidth: page.width * scaleUp,
        fullHeight: page.height * scaleUp,
      );

      var imageUI = await pageImage?.createImage();
      var imgBytes = await imageUI?.toByteData(format: ImageByteFormat.png);
      if (imgBytes == null) {
        continue;
      }
      var libImage = img.decodeImage(imgBytes.buffer
          .asUint8List(imgBytes.offsetInBytes, imgBytes.lengthInBytes));
      if (libImage == null) {
        continue;
      }
      height += imageUI?.height ?? 0;
      if ((imageUI?.width ?? 0) > width) {
        width = imageUI?.width ?? 0;
      }

      imageList.add(libImage);
    }

    final img.Image mergedImage = img.Image(width: width, height: height);

    // Merge generated image vertically as vertical-orientated-multi-pdf
    for (var i = 0; i < imageList.length; i++) {
      // one page height
      final onePageImageOffset = height / document.pages.length;

      // offset for actual page from by y axis
      final actualPageOffset = i == 0 ? 0 : onePageImageOffset * i - 1;

      img.compositeImage(
        mergedImage,
        imageList[i],
        srcW: width,
        srcH: onePageImageOffset.round(),
        dstY: actualPageOffset.round(),
      );
    }

    return mergedImage;
  }

  static Future<File?> _imageToFile(img.Image pfdImage) async {
    final imageBytes = Uint8List.fromList(img.encodePng(pfdImage));

    final appDir = await getTemporaryDirectory();
    String path = '${appDir.path}/ocr_temp.png';

    return await File(path).writeAsBytes(imageBytes);
  }
}

class ImagePDF {
  PdfDocument document;
  File file;
  img.Image image;

  ImagePDF({
    required this.document,
    required this.file,
    required this.image,
  });
}
