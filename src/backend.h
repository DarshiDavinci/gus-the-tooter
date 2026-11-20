#pragma once

#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QTimer>

// Starts and stops the Gus overlay (a Quickshell config) and keeps the
// settings it reads from ~/.config/gus/settings.json. The overlay runs on its
// own, so Gus keeps lurking after this window closes.
class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(int minWait READ minWait WRITE setMinWait NOTIFY settingsChanged)
    Q_PROPERTY(int maxWait READ maxWait WRITE setMaxWait NOTIFY settingsChanged)
    Q_PROPERTY(int stay READ stay WRITE setStay NOTIFY settingsChanged)
    Q_PROPERTY(bool sound READ sound WRITE setSound NOTIFY settingsChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY settingsChanged)
    Q_PROPERTY(QStringList toots READ toots WRITE setToots NOTIFY settingsChanged)
    Q_PROPERTY(QStringList allToots READ allToots CONSTANT)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    static constexpr int MinWaitFloor = 3, WaitCeiling = 300, StayFloor = 2, StayCeiling = 30;

    explicit Backend(const QString &configDirectory = {}, const QString &overlayDirectory = {},
                     const QString &qs = {}, QObject *parent = nullptr);
    ~Backend() override;

    bool running() const { return m_running; }
    int minWait() const { return m_minWait; }
    int maxWait() const { return m_maxWait; }
    int stay() const { return m_stay; }
    bool sound() const { return m_sound; }
    int volume() const { return m_volume; }
    QStringList toots() const { return m_toots; }
    QString error() const { return m_error; }
    static QStringList allToots();

    void setMinWait(int seconds);
    void setMaxWait(int seconds);
    void setStay(int seconds);
    void setSound(bool on);
    void setVolume(int percent);
    void setToots(const QStringList &ids);

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void toggle() { m_running ? stop() : start(); }
    Q_INVOKABLE void summon();
    Q_INVOKABLE void preview(const QString &id);
    Q_INVOKABLE void setTootEnabled(const QString &id, bool enabled);
    Q_INVOKABLE void refresh();

    bool load();
    bool save();
    QString settingsPath() const;
    QString overlayDirectory() const { return m_overlay; }
    static QString defaultOverlayDirectory();

signals:
    void runningChanged();
    void settingsChanged();
    void errorChanged();

private:
    void setError(const QString &message);
    void setRunning(bool running);
    void changed();
    bool canRunOverlay();

    QString m_config, m_overlay, m_qs;
    bool m_running = false;
    int m_minWait = 6, m_maxWait = 20, m_stay = 6, m_volume = 80;
    bool m_sound = true;
    QStringList m_toots = allToots();
    QString m_error;
    QProcess m_list;
    QTimer m_poll, m_saveLater;
};
