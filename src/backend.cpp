#include "backend.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>

Backend::Backend(const QString &configDirectory, const QString &overlayDirectory, const QString &qs, QObject *parent)
    : QObject(parent),
      m_config(!configDirectory.isEmpty() ? configDirectory
               : QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + "/gus"),
      m_overlay(!overlayDirectory.isEmpty() ? overlayDirectory : defaultOverlayDirectory()),
      m_qs(!qs.isEmpty() ? qs : QStandardPaths::findExecutable("qs")) {
    load();

    // Sliders change settings many times a second; the overlay only needs the last value.
    m_saveLater.setSingleShot(true);
    m_saveLater.setInterval(250);
    connect(&m_saveLater, &QTimer::timeout, this, &Backend::save);

    // Gus can be stopped from elsewhere (a crash, `qs kill`), so ask Quickshell
    // whether he is still running instead of trusting what this window did last.
    connect(&m_list, &QProcess::finished, this, [this](int code, QProcess::ExitStatus) {
        setRunning(code == 0 && m_list.readAllStandardOutput().contains("Process ID"));
    });
    m_poll.setInterval(1500);
    connect(&m_poll, &QTimer::timeout, this, &Backend::refresh);
    m_poll.start();
    refresh();
}

Backend::~Backend() {
    if (m_list.state() != QProcess::NotRunning) {
        m_list.kill();
        m_list.waitForFinished(500);
    }
}

QStringList Backend::allToots() {
    return {"tuba", "squeaker", "machinegun", "wetflap", "question", "opera", "sbd"};
}

QString Backend::defaultOverlayDirectory() {
    const QString fromEnvironment = qEnvironmentVariable("GUS_OVERLAY_DIR");
    if (!fromEnvironment.isEmpty())
        return fromEnvironment;
    // Next to the binary when run from build/, the package's copy otherwise.
    const QString besideBinary = QCoreApplication::applicationDirPath() + "/overlay";
    if (QFileInfo::exists(besideBinary + "/shell.qml"))
        return besideBinary;
    return "/usr/share/gus/overlay";
}

QString Backend::settingsPath() const { return m_config + "/settings.json"; }

bool Backend::load() {
    QFile file(settingsPath());
    if (!file.open(QIODevice::ReadOnly))
        return false;
    const QJsonObject s = QJsonDocument::fromJson(file.readAll()).object();
    m_minWait = qBound(MinWaitFloor, s.value("minWait").toInt(m_minWait), WaitCeiling);
    m_maxWait = qBound(m_minWait, s.value("maxWait").toInt(m_maxWait), WaitCeiling);
    m_stay = qBound(StayFloor, s.value("stay").toInt(m_stay), StayCeiling);
    m_sound = s.value("sound").toBool(m_sound);
    m_volume = qBound(0, s.value("volume").toInt(m_volume), 100);
    if (s.value("toots").isArray()) {
        QStringList ids;
        for (const auto &v : s.value("toots").toArray())
            if (allToots().contains(v.toString()))
                ids << v.toString();
        m_toots = ids;
    }
    emit settingsChanged();
    return true;
}

bool Backend::save() {
    m_saveLater.stop();
    if (!QDir().mkpath(m_config)) {
        setError(tr("Couldn't create %1.").arg(m_config));
        return false;
    }
    QJsonObject s{{"minWait", m_minWait}, {"maxWait", m_maxWait}, {"stay", m_stay},
                  {"sound", m_sound}, {"volume", m_volume}, {"toots", QJsonArray::fromStringList(m_toots)}};
    // QSaveFile writes beside the target and renames, so the overlay never reads half a file.
    QSaveFile file(settingsPath());
    if (!file.open(QIODevice::WriteOnly) || file.write(QJsonDocument(s).toJson()) < 0 || !file.commit()) {
        setError(tr("Couldn't save settings to %1.").arg(settingsPath()));
        return false;
    }
    return true;
}

void Backend::changed() {
    emit settingsChanged();
    m_saveLater.start();
}

void Backend::setMinWait(int seconds) {
    seconds = qBound(MinWaitFloor, seconds, WaitCeiling);
    if (seconds == m_minWait) return;
    m_minWait = seconds;
    m_maxWait = qMax(m_maxWait, m_minWait);
    changed();
}

void Backend::setMaxWait(int seconds) {
    seconds = qBound(m_minWait, seconds, WaitCeiling);
    if (seconds == m_maxWait) return;
    m_maxWait = seconds;
    changed();
}

void Backend::setStay(int seconds) {
    seconds = qBound(StayFloor, seconds, StayCeiling);
    if (seconds == m_stay) return;
    m_stay = seconds;
    changed();
}

void Backend::setSound(bool on) {
    if (on == m_sound) return;
    m_sound = on;
    changed();
}

void Backend::setVolume(int percent) {
    percent = qBound(0, percent, 100);
    if (percent == m_volume) return;
    m_volume = percent;
    changed();
}

void Backend::setToots(const QStringList &ids) {
    QStringList known;
    for (const auto &id : allToots())
        if (ids.contains(id))
            known << id;
    if (known == m_toots) return;
    m_toots = known;
    changed();
}

void Backend::setTootEnabled(const QString &id, bool enabled) {
    QStringList ids = m_toots;
    if (enabled && !ids.contains(id)) ids << id;
    if (!enabled) ids.removeAll(id);
    setToots(ids);
}

bool Backend::canRunOverlay() {
    if (m_qs.isEmpty()) {
        setError(tr("Gus needs Quickshell (qs) to appear on screen, and it isn't installed."));
        return false;
    }
    if (!QFileInfo::exists(m_overlay + "/shell.qml")) {
        setError(tr("Gus's overlay is missing from %1. Reinstall the app.").arg(m_overlay));
        return false;
    }
    return true;
}

void Backend::start() {
    if (!canRunOverlay()) return;
    save();
    setError({});
    if (!QProcess::startDetached(m_qs, {"-p", m_overlay, "-d"})) {
        setError(tr("Couldn't start Gus."));
        return;
    }
    setRunning(true);
    QTimer::singleShot(800, this, &Backend::refresh);
}

void Backend::stop() {
    if (m_qs.isEmpty()) return;
    QProcess::startDetached(m_qs, {"kill", "-p", m_overlay});
    setRunning(false);
    QTimer::singleShot(800, this, &Backend::refresh);
}

void Backend::summon() {
    if (!m_running || m_qs.isEmpty()) return;
    QProcess::startDetached(m_qs, {"ipc", "-p", m_overlay, "call", "gus", "summon"});
}

void Backend::preview(const QString &id) {
    if (!allToots().contains(id)) return;
    const QString player = QStandardPaths::findExecutable("pw-play");
    if (player.isEmpty()) {
        setError(tr("Can't play sounds: pw-play (PipeWire) isn't installed."));
        return;
    }
    QProcess::startDetached(player, {QString("--volume=%1").arg(m_volume / 100.0, 0, 'f', 2),
                                     m_overlay + "/sounds/" + id + ".wav"});
}

void Backend::refresh() {
    if (m_qs.isEmpty() || m_list.state() != QProcess::NotRunning) return;
    m_list.start(m_qs, {"list", "-p", m_overlay});
}

void Backend::setRunning(bool running) {
    if (running == m_running) return;
    m_running = running;
    emit runningChanged();
}

void Backend::setError(const QString &message) {
    if (message == m_error) return;
    m_error = message;
    emit errorChanged();
}
