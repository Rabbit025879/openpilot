/*  JLL 2023.3.11
from /tools/replay/route.cc
for 230309, 230310
*/
#include "tools/replay/routeJLL.h"
#include "tools/replay/replayJLL.h"
#include "tools/replay/util.h"

#include <QDir>
#include <QEventLoop>
#include <QJsonArray>
#include <QJsonDocument>
#include <QRegExp>
#include <QtConcurrent>

#include <array>

#include "system/hardware/hw.h"
#include "selfdrive/ui/qt/api.h"

Route::Route(const QString &route, const QString &data_dir) : data_dir_(data_dir) {
  route_ = parseRoute(route);
  qDebug() << "//--- route_.str = " << route_.str;
  qDebug() << "//--- data_dir_ = " << data_dir_;
    //--- route =  "8bfda98c9c9e4291|2020-05-11--03-00-57--61"
    //--- route_.str =  "8bfda98c9c9e4291|2020-05-11--03-00-57"
    //--- data_dir =  "dataC/8bfda98c9c9e4291|2020-05-11--03-00-57"
    //--- data_dir_ =  "dataC/8bfda98c9c9e4291|2020-05-11--03-00-57"
}

RouteIdentifier Route::parseRoute(const QString &str) {
  QRegExp rx(R"(^(?:([a-z0-9]{16})([|_/]))?(\d{4}-\d{2}-\d{2}--\d{2}-\d{2}-\d{2})(?:(--|/)(\d*))?$)");
  if (rx.indexIn(str) == -1) return {};

  const QStringList list = rx.capturedTexts();
    //--- list[2] =  "/"
    //--- list[5] =  "61"
    //--- segment_id = list[5].toInt() =  61
  return {.dongle_id = list[1], .timestamp = list[3], .segment_id = list[5].toInt(), .str = list[1] + "|" + list[3]};
}

bool Route::load() {
    //--- data_dir_.isEmpty() =  false
  if (route_.str.isEmpty() || (data_dir_.isEmpty() && route_.dongle_id.isEmpty())) {
    rInfo("invalid route format");
    return false;
  }
  date_time_ = QDateTime::fromString(route_.timestamp, "yyyy-MM-dd--HH-mm-ss");
    //--- date_time_ =  QDateTime(2020-05-11 03:00:57.000 CST Qt::LocalTime)
  return data_dir_.isEmpty() ? loadFromServer() : loadFromLocal();
}

bool Route::loadFromServer() {
  QEventLoop loop;
  HttpRequest http(nullptr, !Hardware::PC());
  QObject::connect(&http, &HttpRequest::requestDone, [&](const QString &json, bool success, QNetworkReply::NetworkError error) {
    if (error == QNetworkReply::ContentAccessDenied || error == QNetworkReply::AuthenticationRequiredError) {
      qWarning() << ">>  Unauthorized. Authenticate with tools/lib/auth.py  <<";
    }

    loop.exit(success ? loadFromJson(json) : 0);
  });
  http.sendRequest("https://api.commadotai.com/v1/route/" + route_.str + "/files");
  return loop.exec();
}

bool Route::loadFromJson(const QString &json) {
  QRegExp rx(R"(\/(\d+)\/)");
  for (const auto &value : QJsonDocument::fromJson(json.trimmed().toUtf8()).object()) {
    for (const auto &url : value.toArray()) {
      QString url_str = url.toString();
      if (rx.indexIn(url_str) != -1) {
        addFileToSegment(rx.cap(1).toInt(), url_str);
      }
    }
  }
  return !segments_.empty();
}

bool Route::loadFromLocal() {
  QDir log_dir(data_dir_);
    //--- data_dir_ =  "dataC/8bfda98c9c9e4291|2020-05-11--03-00-57"
    //qDebug() << "//--- log_dir = " << log_dir;
    //--- log_dir =  QDir( "dataC/8bfda98c9c9e4291|2020-05-11--03-00-57" , nameFilters = { "*" },
    // QT5 TUTORIAL QDIR - 2020
  for (const auto &folder : log_dir.entryList(QDir::Dirs | QDir::NoDot | QDir::NoDotDot, QDir::NoSort)) {
      // QDir::Dirs (Value 0x001), QDir::NoDot (0x2000), the bitwise OR operator |
    qDebug() << "//--- folder = " << folder;
      //--- folder =  "61"  // new
      //--- folder =  "8bfda98c9c9e4291|2020-05-11--03-00-57"  // old
      //int pos = folder.lastIndexOf("--");
      //--- pos =  27
      //qDebug() << "//--- folder.left(pos) = " << folder.left(pos);
      //--- folder.left(pos) =  "8bfda98c9c9e4291|2020-05-11"
      //qDebug() << "//--- route_.timestamp = " << route_.timestamp;
      //--- route_.timestamp =  "2020-05-11--03-00-57"
      // JLL: int QString::lastIndexOf(const QString &str, int from = -1
      // Returns the index position of the last occurrence of the string str in
      //   this string, searching backward from index position from.
    if (folder.toInt() != -1) {
      //if (pos != -1 && folder.left(pos) == route_.timestamp) {
      const int seg_num = folder.toInt();
        //const int seg_num = folder.mid(pos + 2).toInt();
        //--- folder.mid(pos + 2) =  "03-00-57"
      QDir segment_dir(log_dir.filePath(folder));
        //--- segment_dir =  QDir( "dataC/8bfda98c9c9e4291|2020-05-11--03-00-57/61" , nameFilters = { "*" },
        //qDebug() << "//--- segment_dir.entryList(QDir::Files) = " << segment_dir.entryList(QDir::Files);
        //--- segment_dir.entryList(QDir::Files) =  ("fcamera.hevc", "rlog.bz2")
      for (const auto &f : segment_dir.entryList(QDir::Files)) {
        addFileToSegment(seg_num, segment_dir.absoluteFilePath(f));
          //addFileToSegment(folder.toInt(), segment_dir.absoluteFilePath(f));
          //--- segment_dir.absoluteFilePath(f) =  "/home/jinn/openpilot/tools/replay/dataC/8bfda98c9c9e4291|2020-05-11--03-00-57/62/fcamera.hevc"
      }
    }
  }
    //qDebug() << "//--- !segments_.empty() = " << !segments_.empty();
    //--- !segments_.empty() =  true
  return !segments_.empty();
}

void Route::addFileToSegment(int n, const QString &file) {
  QString name = QUrl(file).fileName();

  const int pos = name.lastIndexOf("--");
  name = pos != -1 ? name.mid(pos + 2) : name;

  if (name == "rlog.bz2" || name == "rlog") {
    segments_[n].rlog = file;
  } else if (name == "qlog.bz2" || name == "qlog") {
    segments_[n].qlog = file;
  } else if (name == "fcamera.hevc") {
    segments_[n].road_cam = file;
  } else if (name == "dcamera.hevc") {
    segments_[n].driver_cam = file;
  } else if (name == "ecamera.hevc") {
    segments_[n].wide_road_cam = file;
  } else if (name == "qcamera.ts") {
    segments_[n].qcamera = file;
  }
}

// class Segment

Segment::Segment(int n, const SegmentFile &files, uint32_t flags,
                 const std::set<cereal::Event::Which> &allow)
    : seg_num(n), flags(flags), allow(allow) {
  // [RoadCam, DriverCam, WideRoadCam, log]. fallback to qcamera/qlog
  const std::array file_list = {
      (flags & REPLAY_FLAG_QCAMERA) || files.road_cam.isEmpty() ? files.qcamera : files.road_cam,
      flags & REPLAY_FLAG_DCAM ? files.driver_cam : "",
      flags & REPLAY_FLAG_ECAM ? files.wide_road_cam : "",
      files.rlog.isEmpty() ? files.qlog : files.rlog,
  };
  for (int i = 0; i < file_list.size(); ++i) {
    if (!file_list[i].isEmpty() && (!(flags & REPLAY_FLAG_NO_VIPC) || i >= MAX_CAMERAS)) {
      ++loading_;
      synchronizer_.addFuture(QtConcurrent::run(this, &Segment::loadFile, i, file_list[i].toStdString()));
    }
  }
}

Segment::~Segment() {
  disconnect();
  abort_ = true;
  synchronizer_.setCancelOnWait(true);
  synchronizer_.waitForFinished();
}

void Segment::loadFile(int id, const std::string file) {
  const bool local_cache = !(flags & REPLAY_FLAG_NO_FILE_CACHE);
  bool success = false;
  if (id < MAX_CAMERAS) {
    frames[id] = std::make_unique<FrameReader>();
    success = frames[id]->load(file, flags & REPLAY_FLAG_NO_HW_DECODER, &abort_, local_cache, 20 * 1024 * 1024, 3);
  } else {
    log = std::make_unique<LogReader>();
    success = log->load(file, &abort_, allow, local_cache, 0, 3);
  }

  if (!success) {
    // abort all loading jobs.
    abort_ = true;
  }

  if (--loading_ == 0) {
    emit loadFinished(!abort_);
  }
}
