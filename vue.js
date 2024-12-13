const app = new Vue({
  el: '#app',
  data: {
    ui: false,
    car: false,
    lastType: null,

    player: {
      ping: 20,
    },

    vehicle: {
      multipler: 'KM/H',
      status: {
        speed: 150,
        fuel: 50,
        engine: 50,
        rpm: 35,
      },
      light: false,
      door: false,
      seatbelt: false,
      engine: false,
      speed: false,
      health: false,
      currentGear: 1,
      totalGears: 5,
    },
    hud: {
      location: {
        location1: 'Vespucci Boulevard',
        location2: 'Vespucci',
      },
      health: {
        status: 100,
      },
      armor: {
        status: 0,
      },
      hunger: {
        status: 60,
      },
      thirst: { 
        status: 50,
      },
      stamina: {
        status: 100,
      },
      oxygen: {
        status: 100,
      },
      stress: {
        status: 50,
      },
      parachute: {
        variable: false,
        status: 0,
      },
      microphone: {
        status: 100,
      },
      voice: false,
    },
  },
  methods: {
    changeGear(newGear) {
      const gearElement = this.$refs.currentGearNumber;
      anime({
        targets: gearElement,
        scale: [1, 0.9],
        opacity: [1, 0.7],
        duration: 200,
        easing: 'easeInOutQuad',
        complete: () => {
          this.vehicle.currentGear = newGear; 
          this.$nextTick(() => {
            anime({
              targets: gearElement,
              scale: [0.9, 1],
              opacity: [0.7, 1],
              duration: 200,
              easing: 'easeOutQuad',
              complete: () => {
                anime({
                  targets: gearElement,
                  keyframes: [
                    { translateY: -2 },
                    { translateY: 2 },
                    { translateY: -1 },
                    { translateY: 1 },
                    { translateY: 0 }
                  ],
                  duration: 300,
                  easing: 'easeInOutQuad'
                });
              }
            });
          });
        }
      });
    },   

    handleEventMessage(event) {
      const item = event.data;
      switch (item.data) {
        case 'NITRO':
          if (this.vehicle && this.vehicle.status) {
            this.vehicle.status.nitrous = item.value || item[1] || 0;
          }
          break;
        case 'CAR':
          this.car = true;
          if (this.vehicle && typeof this.vehicle === 'object') {
            this.vehicle.status.speed = item.speed || this.vehicle.status.speed;
            this.vehicle.status.fuel = item.fuel || this.vehicle.status.fuel;
            this.vehicle.status.engine = item.engine || this.vehicle.status.engine;
            this.vehicle.status.rpm = item.rpm || this.vehicle.status.rpm;
            this.vehicle.seatbelt = item.seatbelt !== undefined ? item.seatbelt : this.vehicle.seatbelt;
            this.vehicle.light = item.state !== undefined ? item.state : this.vehicle.light;
            this.vehicle.door = item.door !== undefined ? item.door : this.vehicle.door;
            this.vehicle.multipler = item.multipler || this.vehicle.multipler;
            if (typeof this.changeGear === 'function' && item.gear !== undefined) {
              this.changeGear(item.gear);
            } else {
              console.error("changeGear is not a function or gear is undefined");
            }
          } else {
            console.error("this.vehicle is not defined or is not an object");
          }
          break;
        case 'CIVIL':
          this.car = false;
          break;

        case 'SOUND':
              switch (item.type) {
                  case 'isTalking':
                    if (item.value){
                      this.hud.voice = true;
                    }else {
                      this.hud.voice = false;
                    }
                      break;
                  case 'mic_level':
                      this.hud.microphone.status = item.value;
                      break;
                  case 'isMuted':
                      this.hud.voice = false;
                    break;
            }
        break

        case 'STATUS':
          if (this.hud) {
            if (item.hunger !== undefined) this.hud.hunger.status = item.hunger;
            if (item.thirst !== undefined) this.hud.thirst.status = item.thirst;
            this.ui = true;
            this.car = false;
          }
          break;
         case 'EXIT':
          this.ui = item.args;
         break 
        case 'STAMINA':
          this.hud.stamina.status = item.value;
          console.log(item.value)
          break;
        case 'OXYGEN':
          console.log('OXYGEN', item.value)
           this.hud.oxygen.status = item.value;
          break;
        case 'PARACHUTE':
          if (this.hud && this.hud.parachute) {
            this.hud.parachute.status = item.value !== undefined ? item.value : this.hud.parachute.status;
          }
          break;
        case 'STRESS':
          if (this.hud && this.hud.stress) {
            this.hud.stress.status = item.stress !== undefined ? item.stress : this.hud.stress.status;
          }
          break;
        case 'PARACHUTE_SET':
          if (this.hud && this.hud.parachute) {
            this.hud.parachute.variable = item.value !== undefined ? item.value : this.hud.parachute.variable;
          }
          break;
        case 'HEALTH':
          this.hud.health.status = item[1];
          break;
        case 'ARMOR':
            this.hud.armor.status = item[1];
          break;
        default:
          console.warn(`Unhandled event data type: ${item.data}`);
      }
    },
  },
  created() {
    // Metodu Vue instance'ına bağla
    this.handleEventMessage = this.handleEventMessage.bind(this);
    window.addEventListener('message', this.handleEventMessage);
  },
  beforeDestroy() {
    window.removeEventListener('message', this.handleEventMessage);
  },
  computed: {
    divStyle() {
      return {
        position: 'fixed', 
        bottom: this.car ? '18.25rem' : '5.5rem',
        transition: 'bottom 0.5s ease', 
      };
    },
    
    Fuel() {
      return 400 + this.vehicle.status.fuel * 2;
    },
    
    Nitrous() {
      return 300 - this.vehicle.status.nitrous * 2;
    },

    Light() {
      return this.vehicle.light ? '#BFFF38' : '#DFDFDF';
    },

    Door() {
      return this.vehicle.door ? '#BFFF38' : '#FFFFFF';
    },

    Seatbelt() {
      console.log(this.vehicle.seatbelt)
      return this.vehicle.seatbelt ? '#BBDE1A' : '#FFFFFF';
    },
    
    Engine() {
      return this.vehicle.engine ? '#BBDE1A' : '#FFFFFF';
    },

    Speed() {
      return this.vehicle.speed ? '#BBDE1A' : '#FFFFFF';
    },
    
    GetVehicleHealth() {
      return this.vehicle.status.speed > 0 ? 'red' : '#FFFFFF';
    },

    GetPlayerPing() {
      return this.player.ping > 50 ? 'red' : 'green';
    },   

    leftGear() {
      return this.vehicle.currentGear > 1 ? this.vehicle.currentGear - 1 : this.vehicle.totalGears;
    },

    rightGear() {
      return this.vehicle.currentGear < this.vehicle.totalGears ? this.vehicle.currentGear + 1 : 1;
    },

    formattedSpeed() {
      let speed = Math.floor(this.vehicle.status.speed); 
      if (speed < 100) {
        return `<tspan fill="grey">0</tspan><tspan fill="white">${speed}</tspan>`;
      } else {
        return `<tspan fill="white">${speed}</tspan>`;
      }
    },

    calculatedHeight() {
      return (value) => {
        const maxHeight = 26.0717;
        return maxHeight * (value / 46.1);
      }
    },
  },
});
